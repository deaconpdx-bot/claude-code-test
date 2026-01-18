# Data Model - Stone Forest App

## Overview

This document defines the complete database schema for the Stone Forest App implemented in Sprint 002A. All tables use Supabase (PostgreSQL) with Row Level Security (RLS) enabled.

**Last Updated:** Sprint 002A (2026-01-18)

---

## Table of Contents

1. [Core Tables](#core-tables) - Organizations, Users, Projects
2. [Invoice Tables](#invoice-tables) - Invoices, Invoice Events
3. [Proof/File Tables](#prooffile-tables) - File Assets, Approval Events
4. [Shipment Tables](#shipment-tables) - Shipments, Shipment Events
5. [ENUM Types](#enum-types)
6. [Computed Columns](#computed-columns)
7. [Indexes](#indexes)
8. [Relationships](#relationships)
9. [Data Integrity Rules](#data-integrity-rules)

---

## Core Tables

### Organizations

Represents both internal (Stone Forest) and customer organizations.

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('internal', 'customer')),
  contact_email VARCHAR(255),
  contact_phone VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_organizations_type ON organizations(type);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_organizations_updated_at
  BEFORE UPDATE ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Field Descriptions:**

- `type`: Either 'internal' (Stone Forest staff) or 'customer' (client companies)
- `contact_email`: Primary contact email for the organization
- `contact_phone`: Primary contact phone number

---

### Users

Application users (internal staff and customer contacts).

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'staff', 'customer')),
  auth_user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth ON users(auth_user_id);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Field Descriptions:**

- `organization_id`: Each user belongs to one organization
- `email`: Unique email address for login and notifications
- `role`: User role (admin, staff, or customer)
- `auth_user_id`: Link to Supabase Auth user (null if not authenticated yet)

---

### Projects

Customer projects (print jobs, design work, etc.).

```sql
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'on_hold', 'completed', 'cancelled')),
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_projects_organization ON projects(organization_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_created_by ON projects(created_by);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Field Descriptions:**

- `name`: Project name/title (e.g., "Q1 2026 Product Catalog")
- `description`: Detailed project scope and requirements
- `status`: Current project status (active, on_hold, completed, cancelled)
- `created_by`: Staff member who created this project

---

## Invoice Tables

### Invoices

Invoice records with payment tracking and deposit support.

```sql
CREATE TYPE invoice_status AS ENUM (
  'draft',      -- Not yet sent to customer
  'sent',       -- Sent to customer, awaiting payment
  'paid',       -- Fully paid
  'overdue',    -- Past due date and not paid
  'cancelled'   -- Invoice voided/cancelled
);

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

CREATE INDEX idx_invoices_project ON invoices(project_id);
CREATE INDEX idx_invoices_organization ON invoices(organization_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_invoice_number ON invoices(invoice_number);
CREATE INDEX idx_invoices_created_by ON invoices(created_by);

-- Computed column for balance due (stored for efficient querying)
ALTER TABLE invoices ADD COLUMN balance_due INTEGER
  GENERATED ALWAYS AS (amount_total - amount_paid) STORED;

CREATE INDEX idx_invoices_balance_due ON invoices(balance_due);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Field Descriptions:**

- `invoice_number`: Unique identifier like "INV-2026-001"
- `issue_date`: When invoice was created/sent
- `due_date`: Payment deadline
- `amount_*`: All amounts in cents (e.g., $100.00 = 10000)
- `deposit_required`: If true, deposit must be paid before work begins
- `deposit_amount`: Amount of deposit required (in cents)
- `deposit_paid`: Whether deposit has been received
- `status`: Current state of invoice
  - `draft`: Not yet sent to customer
  - `sent`: Sent to customer, awaiting payment
  - `paid`: Fully paid
  - `overdue`: Past due_date and not paid
  - `cancelled`: Invoice voided

---

### Invoice Events

Audit log for invoice lifecycle events and automated reminders.

```sql
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

CREATE INDEX idx_invoice_events_invoice ON invoice_events(invoice_id);
CREATE INDEX idx_invoice_events_type ON invoice_events(event_type);
CREATE INDEX idx_invoice_events_created ON invoice_events(created_at DESC);
```

**Event Data Examples:**

```jsonb
-- reminder_7day event
{
  "days_until_due": 7,
  "amount_due": 50000,
  "email_sent_to": "customer@example.com",
  "n8n_workflow_id": "abc123"
}

-- payment_received event
{
  "amount": 50000,
  "payment_method": "stripe",
  "transaction_id": "ch_xyz789"
}

-- viewed event
{
  "viewer_ip": "192.168.1.1",
  "viewer_user_agent": "Mozilla/5.0..."
}
```

---

## Proof/File Tables

### File Assets

Stores all uploaded files including proofs, artwork, and attachments with version control.

```sql
CREATE TYPE file_type AS ENUM (
  'proof',           -- Proof PDF for customer review
  'artwork',         -- Final artwork files
  'reference',       -- Reference materials
  'attachment'       -- General attachments
);

CREATE TYPE approval_status AS ENUM (
  'pending',         -- Awaiting customer review
  'approved',        -- Customer approved
  'rejected',        -- Customer rejected (changes needed)
  'revision',        -- Internal revision in progress
  'final'            -- Final approved version
);

CREATE TABLE file_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- File metadata
  file_name VARCHAR(255) NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  file_type file_type NOT NULL,
  mime_type VARCHAR(100) NOT NULL,

  -- Storage path (Supabase Storage)
  storage_bucket VARCHAR(100) NOT NULL DEFAULT 'file-assets',
  storage_path VARCHAR(500) NOT NULL,

  -- Version control
  version_number INTEGER NOT NULL DEFAULT 1,
  is_current_version BOOLEAN NOT NULL DEFAULT true,
  parent_file_id UUID REFERENCES file_assets(id) ON DELETE SET NULL,

  -- Approval workflow (for proofs)
  approval_status approval_status,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,

  -- Metadata
  uploaded_by UUID NOT NULL REFERENCES users(id),
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_file_assets_project ON file_assets(project_id);
CREATE INDEX idx_file_assets_organization ON file_assets(organization_id);
CREATE INDEX idx_file_assets_file_type ON file_assets(file_type);
CREATE INDEX idx_file_assets_approval_status ON file_assets(approval_status);
CREATE INDEX idx_file_assets_is_current ON file_assets(is_current_version) WHERE is_current_version = true;
CREATE INDEX idx_file_assets_parent ON file_assets(parent_file_id);
CREATE INDEX idx_file_assets_uploaded_by ON file_assets(uploaded_by);
CREATE INDEX idx_file_assets_created ON file_assets(created_at DESC);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_file_assets_updated_at
  BEFORE UPDATE ON file_assets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Field Descriptions:**

- `storage_bucket`: Supabase Storage bucket name (default: 'file-assets')
- `storage_path`: Path within bucket (e.g., 'project-id/filename-uuid.pdf')
- `version_number`: Version number for this file (1, 2, 3...)
- `is_current_version`: True if this is the latest version
- `parent_file_id`: Link to previous version if this is a revision
- `approval_status`: Approval state for proofs (null for non-proof files)

---

### Approval Events

Audit log for proof approval workflow events.

```sql
CREATE TABLE approval_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_asset_id UUID NOT NULL REFERENCES file_assets(id) ON DELETE CASCADE,

  -- Event details
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,

  -- Who triggered this event
  triggered_by UUID REFERENCES users(id),
  triggered_by_system VARCHAR(50),

  -- Email notification tracking
  notification_sent BOOLEAN NOT NULL DEFAULT false,
  notification_sent_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_approval_events_file_asset ON approval_events(file_asset_id);
CREATE INDEX idx_approval_events_type ON approval_events(event_type);
CREATE INDEX idx_approval_events_created ON approval_events(created_at DESC);
CREATE INDEX idx_approval_events_notification ON approval_events(notification_sent) WHERE notification_sent = false;
```

**Event Types:**
- `uploaded`: File was uploaded
- `sent_for_review`: Sent to customer for approval
- `approved`: Customer approved the proof
- `rejected`: Customer rejected with feedback
- `revision_uploaded`: New revision uploaded

---

## Shipment Tables

### Shipments

Tracks shipments for project deliveries with carrier integration.

```sql
CREATE TYPE shipment_status AS ENUM (
  'pending',         -- Order received, not yet shipped
  'preparing',       -- Being prepared for shipment
  'shipped',         -- In transit with carrier
  'in_transit',      -- Actively moving in carrier network
  'out_for_delivery',-- Out for final delivery
  'delivered',       -- Successfully delivered
  'failed',          -- Delivery failed (will retry)
  'cancelled',       -- Shipment cancelled
  'returned'         -- Returned to sender
);

CREATE TYPE shipping_carrier AS ENUM (
  'usps',            -- US Postal Service
  'ups',             -- UPS
  'fedex',           -- FedEx
  'dhl',             -- DHL
  'other',           -- Other carriers
  'hand_delivery'    -- Hand-delivered by staff
);

CREATE TABLE shipments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- Shipment details
  shipment_number VARCHAR(50) UNIQUE NOT NULL,
  carrier shipping_carrier NOT NULL,
  tracking_number VARCHAR(100),
  tracking_url VARCHAR(500),

  -- Status tracking
  status shipment_status NOT NULL DEFAULT 'pending',
  status_updated_at TIMESTAMPTZ,

  -- Shipping dates
  expected_ship_date DATE,
  actual_ship_date DATE,
  expected_delivery_date DATE,
  actual_delivery_date DATE,

  -- Shipping addresses (JSON for flexibility)
  ship_from_address JSONB,
  ship_to_address JSONB NOT NULL,

  -- Package details
  package_count INTEGER NOT NULL DEFAULT 1,
  weight_lbs DECIMAL(10, 2),
  dimensions_inches VARCHAR(50), -- e.g., "12x8x4"

  -- Cost tracking (in cents)
  shipping_cost_cents INTEGER,
  insurance_cost_cents INTEGER DEFAULT 0,

  -- Notes and metadata
  notes TEXT,
  internal_notes TEXT, -- Not visible to customers

  -- Tracking
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shipments_project ON shipments(project_id);
CREATE INDEX idx_shipments_organization ON shipments(organization_id);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_carrier ON shipments(carrier);
CREATE INDEX idx_shipments_tracking_number ON shipments(tracking_number);
CREATE INDEX idx_shipments_shipment_number ON shipments(shipment_number);
CREATE INDEX idx_shipments_expected_delivery ON shipments(expected_delivery_date);
CREATE INDEX idx_shipments_actual_delivery ON shipments(actual_delivery_date);
CREATE INDEX idx_shipments_created ON shipments(created_at DESC);

-- Trigger to auto-update updated_at
CREATE TRIGGER update_shipments_updated_at
  BEFORE UPDATE ON shipments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Address JSON Format:**
```json
{
  "street": "123 Main St",
  "city": "Denver",
  "state": "CO",
  "zip": "80202",
  "country": "US"
}
```

---

### Shipment Events

Audit log for shipment tracking updates and status changes.

```sql
CREATE TABLE shipment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,

  -- Event details
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,

  -- Status change tracking
  old_status shipment_status,
  new_status shipment_status,

  -- Location tracking (from carrier updates)
  location VARCHAR(255),
  location_coordinates POINT,

  -- Who triggered this event
  triggered_by UUID REFERENCES users(id),
  triggered_by_system VARCHAR(50),

  -- Notification tracking
  notification_sent BOOLEAN NOT NULL DEFAULT false,
  notification_sent_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shipment_events_shipment ON shipment_events(shipment_id);
CREATE INDEX idx_shipment_events_type ON shipment_events(event_type);
CREATE INDEX idx_shipment_events_created ON shipment_events(created_at DESC);
CREATE INDEX idx_shipment_events_notification ON shipment_events(notification_sent) WHERE notification_sent = false;
CREATE INDEX idx_shipment_events_status_change ON shipment_events(new_status) WHERE new_status IS NOT NULL;
```

**Event Types:**
- `created`: Shipment record created
- `shipped`: Package picked up by carrier
- `status_update`: Tracking status updated
- `delivered`: Successfully delivered
- `failed_delivery`: Delivery attempt failed

---

## ENUM Types

All ENUM types defined in the schema:

**Invoice Status:**
- `draft`, `sent`, `paid`, `overdue`, `cancelled`

**Invoice Event Type:**
- `created`, `sent`, `viewed`, `payment_received`, `payment_partial`, `deposit_received`
- `reminder_7day`, `reminder_due`, `reminder_overdue`, `marked_overdue`, `cancelled`

**File Type:**
- `proof`, `artwork`, `reference`, `attachment`

**Approval Status:**
- `pending`, `approved`, `rejected`, `revision`, `final`

**Shipment Status:**
- `pending`, `preparing`, `shipped`, `in_transit`, `out_for_delivery`, `delivered`, `failed`, `cancelled`, `returned`

**Shipping Carrier:**
- `usps`, `ups`, `fedex`, `dhl`, `other`, `hand_delivery`

---

## Computed Columns

### invoices.balance_due

```sql
balance_due INTEGER GENERATED ALWAYS AS (amount_total - amount_paid) STORED
```

Automatically calculates the remaining balance on an invoice. This is a stored computed column that is indexed for efficient queries.

---

## Indexes

All indexes created in the schema are listed below:

### Organizations
- `idx_organizations_type` - Filter by organization type

### Users
- `idx_users_organization` - Find users by organization
- `idx_users_email` - Email lookups during authentication
- `idx_users_auth` - Link to Supabase Auth users

### Projects
- `idx_projects_organization` - Find projects by customer
- `idx_projects_status` - Filter by project status
- `idx_projects_created_by` - Track who created projects

### Invoices
- `idx_invoices_project` - Find invoices by project
- `idx_invoices_organization` - Find invoices by customer
- `idx_invoices_status` - Filter by invoice status
- `idx_invoices_due_date` - Critical for reminder workflows
- `idx_invoices_invoice_number` - Fast invoice number lookups
- `idx_invoices_created_by` - Track who created invoices
- `idx_invoices_balance_due` - Find invoices with outstanding balances

### Invoice Events
- `idx_invoice_events_invoice` - Find events for an invoice
- `idx_invoice_events_type` - Filter by event type
- `idx_invoice_events_created` - Chronological sorting (DESC)

### File Assets
- `idx_file_assets_project` - Find files by project
- `idx_file_assets_organization` - RLS filtering
- `idx_file_assets_file_type` - Filter by file type
- `idx_file_assets_approval_status` - Find pending approvals
- `idx_file_assets_is_current` - Partial index for current versions only
- `idx_file_assets_parent` - Version history chains
- `idx_file_assets_uploaded_by` - Track user uploads
- `idx_file_assets_created` - Chronological sorting (DESC)

### Approval Events
- `idx_approval_events_file_asset` - Find events for a file
- `idx_approval_events_type` - Filter by event type
- `idx_approval_events_created` - Chronological sorting (DESC)
- `idx_approval_events_notification` - Partial index for pending notifications

### Shipments
- `idx_shipments_project` - Find shipments by project
- `idx_shipments_organization` - RLS filtering
- `idx_shipments_status` - Filter by shipment status
- `idx_shipments_carrier` - Filter by carrier
- `idx_shipments_tracking_number` - Quick tracking lookups
- `idx_shipments_shipment_number` - Unique shipment number lookups
- `idx_shipments_expected_delivery` - Find by expected delivery date
- `idx_shipments_actual_delivery` - Delivery date analysis
- `idx_shipments_created` - Chronological sorting (DESC)

### Shipment Events
- `idx_shipment_events_shipment` - Find events for a shipment
- `idx_shipment_events_type` - Filter by event type
- `idx_shipment_events_created` - Chronological sorting (DESC)
- `idx_shipment_events_notification` - Partial index for pending notifications
- `idx_shipment_events_status_change` - Partial index for status changes only

---

## Relationships

```
organizations (1) → (N) users
organizations (1) → (N) projects
organizations (1) → (N) invoices
organizations (1) → (N) file_assets
organizations (1) → (N) shipments

users (1) → (N) projects (created_by)
users (1) → (N) invoices (created_by)
users (1) → (N) file_assets (uploaded_by)
users (1) → (N) file_assets (approved_by)
users (1) → (N) shipments (created_by)

projects (1) → (N) invoices
projects (1) → (N) file_assets
projects (1) → (N) shipments

invoices (1) → (N) invoice_events

file_assets (1) → (N) approval_events
file_assets (1) → (N) file_assets (version history via parent_file_id)

shipments (1) → (N) shipment_events
```

---

## Data Integrity Rules

### Invoice Constraints
1. **Amounts must be non-negative**: All amount fields have `CHECK (amount >= 0)`
2. **Deposit validation**: `deposit_amount_required_when_deposit_required` - If deposit required, deposit amount must be set
3. **Payment validation**: `amount_paid_cannot_exceed_total` - Paid amount cannot exceed total
4. **Deposit timestamp**: `deposit_paid_at_set_when_deposit_paid` - If deposit paid, timestamp must be set
5. **Balance due**: Automatically computed as `amount_total - amount_paid`

### Invoice Status Flow
```
draft → sent → paid
         ↓
      overdue → paid
         ↓
     cancelled
```

**Automated Status Updates:**
- `sent`: Manually set when invoice is emailed to customer
- `overdue`: Automatically set by cron job when `due_date < CURRENT_DATE AND status = 'sent'`
- `paid`: Set when `amount_paid >= amount_total`

### File Version Control
- `parent_file_id` links to previous version
- Only one file with `is_current_version = true` per version chain
- Version numbers increment sequentially (1, 2, 3...)

### Shipment Status Flow
```
pending → preparing → shipped → in_transit → out_for_delivery → delivered
                                    ↓
                                 failed → (retry or cancelled)
                                    ↓
                                 returned
```

---

## Helper Functions

### update_updated_at_column()

Trigger function that automatically updates the `updated_at` timestamp on row updates. Applied to all tables with `updated_at` columns.

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## Notes

- All timestamps use `TIMESTAMPTZ` (timestamp with time zone) for proper timezone handling
- UUIDs are used for all primary keys for better security and distribution
- Amounts stored as integers (cents) to avoid floating-point precision issues
- JSONB used for flexible metadata (event_data, addresses) while maintaining queryability
- Indexes created on foreign keys and frequently queried columns
- RLS enabled on all tables (see [030_RLS_POLICIES.md](030_RLS_POLICIES.md) for details)
- Audit tables (events) are append-only - no update or delete policies
- Cascade deletes ensure referential integrity when parent records are removed
