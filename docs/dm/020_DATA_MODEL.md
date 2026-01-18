# Data Model - Stone Forest App

## Overview

This document defines the database schema for the Stone Forest App. All tables use Supabase (PostgreSQL) with Row Level Security (RLS) enabled.

---

## Tables

### Organizations

Represents both internal (Stone Forest) and customer organizations.

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('internal', 'customer')),
  contact_email VARCHAR(255),
  contact_phone VARCHAR(50),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_organizations_type ON organizations(type);
```

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
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth ON users(auth_user_id);
```

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
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_projects_organization ON projects(organization_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_created_by ON projects(created_by);
```

---

## Invoice Tables (Sprint 001)

### Invoices

Invoice records with payment tracking and deposit support.

```sql
CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'overdue', 'cancelled');

CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  invoice_number VARCHAR(50) UNIQUE NOT NULL,
  issue_date DATE NOT NULL,
  due_date DATE NOT NULL,

  -- Amounts in cents to avoid floating point issues
  amount_subtotal INTEGER NOT NULL,
  amount_tax INTEGER NOT NULL DEFAULT 0,
  amount_total INTEGER NOT NULL,
  amount_paid INTEGER NOT NULL DEFAULT 0,

  -- Deposit tracking
  deposit_required BOOLEAN NOT NULL DEFAULT false,
  deposit_amount INTEGER,
  deposit_paid BOOLEAN NOT NULL DEFAULT false,
  deposit_paid_at TIMESTAMP WITH TIME ZONE,

  -- Status and metadata
  status invoice_status NOT NULL DEFAULT 'draft',
  notes TEXT,

  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_invoices_project ON invoices(project_id);
CREATE INDEX idx_invoices_organization ON invoices(organization_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_invoice_number ON invoices(invoice_number);

-- Computed column for balance due
ALTER TABLE invoices ADD COLUMN balance_due INTEGER GENERATED ALWAYS AS (amount_total - amount_paid) STORED;
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
  'created',
  'sent',
  'viewed',
  'payment_received',
  'payment_partial',
  'deposit_received',
  'reminder_7day',
  'reminder_due',
  'reminder_overdue',
  'marked_overdue',
  'cancelled'
);

CREATE TABLE invoice_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  event_type invoice_event_type NOT NULL,

  -- Event metadata (flexible JSON)
  event_data JSONB,

  -- Who/what triggered this event
  triggered_by UUID REFERENCES users(id),
  triggered_by_system VARCHAR(50), -- e.g., 'n8n', 'cron', 'manual'

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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

## Invoice Status Flow

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

---

## Relationships

```
organizations (1) → (N) projects
organizations (1) → (N) invoices
projects (1) → (N) invoices
invoices (1) → (N) invoice_events
```

---

## Data Integrity Rules

1. **Invoice amounts must be positive**: Check constraint ensures all amounts >= 0
2. **Deposit validation**: If `deposit_required = true`, then `deposit_amount` must be set
3. **Payment tracking**: `amount_paid` cannot exceed `amount_total`
4. **Status transitions**: Only valid transitions allowed (enforced via application logic)

---

## Future Tables (Not in Sprint 001)

These tables will be added in later sprints:

- `file_assets` - Uploaded files (proof PDFs, artwork, etc.)
- `file_versions` - Version history for files
- `approval_events` - Proof approval workflow
- `inventory_items` - Stock tracking
- `shipments` - Order tracking

---

## Notes

- All timestamps use `TIMESTAMP WITH TIME ZONE` for proper timezone handling
- UUIDs are used for all primary keys for better security and distribution
- Amounts stored as integers (cents) to avoid floating-point precision issues
- JSONB used for flexible event metadata while maintaining queryability
- Indexes created on foreign keys and frequently queried columns
