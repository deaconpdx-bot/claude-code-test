-- Migration: Create Invoices and Invoice Events Tables
-- Description: Sets up invoice management system with payment tracking, deposit support,
--              and comprehensive audit logging for invoice lifecycle events.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- CUSTOM TYPES (ENUMS)
-- =============================================================================

-- Invoice status enum for tracking invoice lifecycle
CREATE TYPE invoice_status AS ENUM (
  'draft',      -- Not yet sent to customer
  'sent',       -- Sent to customer, awaiting payment
  'paid',       -- Fully paid
  'overdue',    -- Past due date and not paid
  'cancelled'   -- Invoice voided/cancelled
);

COMMENT ON TYPE invoice_status IS
  'Invoice lifecycle states: draft → sent → paid (or overdue → paid). Can be cancelled at any time.';

-- Invoice event type enum for audit logging
CREATE TYPE invoice_event_type AS ENUM (
  'created',           -- Invoice was created
  'sent',              -- Invoice was emailed to customer
  'viewed',            -- Customer viewed the invoice
  'payment_received',  -- Full payment received
  'payment_partial',   -- Partial payment received
  'deposit_received',  -- Deposit payment received
  'reminder_7day',     -- 7-day reminder sent
  'reminder_due',      -- Due date reminder sent
  'reminder_overdue',  -- Overdue reminder sent
  'marked_overdue',    -- Automatically marked as overdue by system
  'cancelled'          -- Invoice was cancelled
);

COMMENT ON TYPE invoice_event_type IS
  'Event types for invoice audit log - tracks all invoice interactions and automated reminders';

-- =============================================================================
-- INVOICES TABLE
-- =============================================================================

-- Invoices table with payment tracking and deposit support
-- All monetary amounts stored as integers (cents) to avoid floating-point precision issues
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  invoice_number VARCHAR(50) UNIQUE NOT NULL,
  issue_date DATE NOT NULL,
  due_date DATE NOT NULL,

  -- Amounts in cents to avoid floating point issues (e.g., $100.00 = 10000)
  amount_subtotal INTEGER NOT NULL CHECK (amount_subtotal >= 0),
  amount_tax INTEGER NOT NULL DEFAULT 0 CHECK (amount_tax >= 0),
  amount_total INTEGER NOT NULL CHECK (amount_total >= 0),
  amount_paid INTEGER NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),

  -- Deposit tracking
  deposit_required BOOLEAN NOT NULL DEFAULT false,
  deposit_amount INTEGER CHECK (deposit_amount IS NULL OR deposit_amount >= 0),
  deposit_paid BOOLEAN NOT NULL DEFAULT false,
  deposit_paid_at TIMESTAMPTZ,

  -- Status and metadata
  status invoice_status NOT NULL DEFAULT 'draft',
  notes TEXT,

  -- Audit fields
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT deposit_amount_required_when_deposit_required
    CHECK (deposit_required = false OR deposit_amount IS NOT NULL),
  CONSTRAINT amount_paid_cannot_exceed_total
    CHECK (amount_paid <= amount_total),
  CONSTRAINT deposit_paid_at_set_when_deposit_paid
    CHECK (deposit_paid = false OR deposit_paid_at IS NOT NULL)
);

-- Add helpful comments
COMMENT ON TABLE invoices IS
  'Invoice records with payment tracking and deposit support. All amounts stored in cents.';
COMMENT ON COLUMN invoices.invoice_number IS
  'Unique invoice identifier (e.g., "INV-2026-001")';
COMMENT ON COLUMN invoices.issue_date IS
  'Date when invoice was created/sent to customer';
COMMENT ON COLUMN invoices.due_date IS
  'Payment deadline - invoices automatically marked overdue after this date';
COMMENT ON COLUMN invoices.amount_subtotal IS
  'Subtotal before tax in cents (e.g., $100.00 = 10000)';
COMMENT ON COLUMN invoices.amount_tax IS
  'Tax amount in cents';
COMMENT ON COLUMN invoices.amount_total IS
  'Total amount due in cents (subtotal + tax)';
COMMENT ON COLUMN invoices.amount_paid IS
  'Amount paid so far in cents - invoice is fully paid when this equals amount_total';
COMMENT ON COLUMN invoices.deposit_required IS
  'If true, deposit must be paid before work begins';
COMMENT ON COLUMN invoices.deposit_amount IS
  'Required deposit amount in cents (typically 50% of total)';
COMMENT ON COLUMN invoices.deposit_paid IS
  'Whether deposit has been received';
COMMENT ON COLUMN invoices.deposit_paid_at IS
  'Timestamp when deposit was received';
COMMENT ON COLUMN invoices.status IS
  'Current invoice status - see invoice_status type for valid values';
COMMENT ON COLUMN invoices.notes IS
  'Internal notes about the invoice (not shown to customer)';

-- Create indexes for efficient querying
CREATE INDEX idx_invoices_project ON invoices(project_id);
CREATE INDEX idx_invoices_organization ON invoices(organization_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_invoice_number ON invoices(invoice_number);
CREATE INDEX idx_invoices_created_by ON invoices(created_by);

COMMENT ON INDEX idx_invoices_project IS
  'Index for finding all invoices for a specific project';
COMMENT ON INDEX idx_invoices_organization IS
  'Index for finding all invoices for a specific customer organization';
COMMENT ON INDEX idx_invoices_status IS
  'Index for filtering invoices by status (e.g., all overdue invoices)';
COMMENT ON INDEX idx_invoices_due_date IS
  'Index for finding invoices by due date - critical for automated reminder workflows';
COMMENT ON INDEX idx_invoices_invoice_number IS
  'Index for fast invoice number lookups';

-- Add computed column for balance due (total - paid)
-- This is a STORED generated column for efficient querying
ALTER TABLE invoices ADD COLUMN balance_due INTEGER
  GENERATED ALWAYS AS (amount_total - amount_paid) STORED;

COMMENT ON COLUMN invoices.balance_due IS
  'Computed column: remaining balance (amount_total - amount_paid). Updated automatically.';

-- Create index on balance_due for efficient queries
CREATE INDEX idx_invoices_balance_due ON invoices(balance_due);

COMMENT ON INDEX idx_invoices_balance_due IS
  'Index for finding invoices with outstanding balances';

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- INVOICE EVENTS TABLE
-- =============================================================================

-- Audit log for invoice lifecycle events and automated reminders
CREATE TABLE invoice_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  event_type invoice_event_type NOT NULL,

  -- Event metadata (flexible JSON for different event types)
  event_data JSONB,

  -- Who/what triggered this event
  triggered_by UUID REFERENCES users(id),
  triggered_by_system VARCHAR(50), -- e.g., 'n8n', 'cron', 'manual'

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add helpful comments
COMMENT ON TABLE invoice_events IS
  'Audit log for all invoice lifecycle events including automated reminders and payments';
COMMENT ON COLUMN invoice_events.event_type IS
  'Type of event - see invoice_event_type enum for valid values';
COMMENT ON COLUMN invoice_events.event_data IS
  'Flexible JSON data specific to event type (e.g., payment amount, email details, reminder metadata)';
COMMENT ON COLUMN invoice_events.triggered_by IS
  'User who triggered this event (NULL for system-triggered events)';
COMMENT ON COLUMN invoice_events.triggered_by_system IS
  'System that triggered this event: n8n (workflows), cron (scheduled jobs), manual (staff action)';

-- Create indexes for efficient querying
CREATE INDEX idx_invoice_events_invoice ON invoice_events(invoice_id);
CREATE INDEX idx_invoice_events_type ON invoice_events(event_type);
CREATE INDEX idx_invoice_events_created ON invoice_events(created_at DESC);

COMMENT ON INDEX idx_invoice_events_invoice IS
  'Index for finding all events for a specific invoice';
COMMENT ON INDEX idx_invoice_events_type IS
  'Index for filtering events by type (e.g., all payment_received events)';
COMMENT ON INDEX idx_invoice_events_created IS
  'Index for chronological event queries (most recent first)';

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS on both tables (policies will be added in a separate migration)
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_events ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE invoices IS
  'Invoice records with payment tracking and deposit support. All amounts stored in cents. RLS enabled.';
COMMENT ON TABLE invoice_events IS
  'Audit log for all invoice lifecycle events including automated reminders and payments. RLS enabled.';

-- =============================================================================
-- EXAMPLE EVENT DATA STRUCTURES (for documentation)
-- =============================================================================

-- These are just comments showing the expected JSON structure for different event types

/*
Event Data Examples:

1. reminder_7day event:
{
  "days_until_due": 7,
  "amount_due": 50000,
  "email_sent_to": "customer@example.com",
  "n8n_workflow_id": "abc123"
}

2. payment_received event:
{
  "amount": 50000,
  "payment_method": "stripe",
  "transaction_id": "ch_xyz789"
}

3. payment_partial event:
{
  "amount": 25000,
  "payment_method": "check",
  "check_number": "1234",
  "remaining_balance": 25000
}

4. viewed event:
{
  "viewer_ip": "192.168.1.1",
  "viewer_user_agent": "Mozilla/5.0...",
  "view_count": 1
}

5. deposit_received event:
{
  "amount": 27500,
  "payment_method": "wire_transfer",
  "transaction_id": "wire_123",
  "deposit_percentage": 50
}

6. reminder_overdue event:
{
  "days_overdue": 3,
  "amount_due": 50000,
  "email_sent_to": "customer@example.com",
  "reminder_count": 2
}
*/
