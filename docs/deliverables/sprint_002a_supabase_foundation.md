# Sprint 002A: Supabase Foundation

## Overview

**Goal**: Build complete database schema, RLS policies, and Supabase integration for the Stone Forest App.

**Status**: ✅ Complete

**Sprint Duration**: Sprint 002A (2026-01-18)

---

## Deliverables

### 1. SQL Migration Files (8 total)

- [x] **Organizations & Users** (`supabase/migrations/20260118000001_create_profiles_and_customers.sql`)
  - Organizations table (internal + customer)
  - Users table with Supabase Auth integration
  - Helper function for auto-updating timestamps

- [x] **Projects** (`supabase/migrations/20260118000002_create_projects.sql`)
  - Projects table for customer work
  - Status tracking (active, on_hold, completed, cancelled)

- [x] **Invoices** (`supabase/migrations/20260118000003_create_invoices.sql`)
  - Invoices table with payment tracking
  - Invoice Events table for audit logging
  - Deposit support with validation constraints
  - Computed column for balance_due
  - ENUM types for status and event types

- [x] **File Assets & Proofs** (`supabase/migrations/20260118000004_create_proofs.sql`)
  - File Assets table with version control
  - Approval Events table for proof workflow
  - ENUM types for file types and approval status

- [x] **Shipments** (`supabase/migrations/20260118000005_create_shipments.sql`)
  - Shipments table with carrier integration
  - Shipment Events table for tracking updates
  - ENUM types for shipment status and carriers
  - JSONB for flexible address storage

- [x] **RLS Helper Functions** (`supabase/migrations/20260118000006_create_rls_helpers.sql`)
  - `auth.user_role()` - Get current user's role
  - `auth.user_organization_id()` - Get current user's org
  - `auth.user_customer_id()` - Alias for organization_id
  - `auth.is_internal_user()` - Check if Stone Forest employee
  - `auth.is_admin()` - Check if admin role
  - `auth.is_staff()` - Check if admin or staff role

- [x] **RLS Policies** (`supabase/migrations/20260118000007_enable_rls_policies.sql`)
  - Comprehensive policies for all 9 tables
  - Customer data isolation enforced at DB level
  - Internal staff full access
  - Draft invoice protection
  - Proof approval workflow permissions

- [x] **Action Queue View** (`supabase/migrations/20260118000008_create_action_queue_view.sql`)
  - Unified view of actionable items for staff
  - Unpaid deposits, overdue invoices, pending proofs
  - Missing tracking numbers, shipment ETA risks
  - Priority-based sorting

### 2. Seed Data

- [x] **Test Data** (`supabase/seed.sql`)
  - 4 organizations (1 internal, 3 customers)
  - 8 users (4 internal staff, 4 customer users)
  - 9 projects across all customers
  - 9 invoices (various states: draft, sent, paid, overdue)
  - 19 invoice events (audit trail)
  - 8 file assets (proofs with version history)
  - 7 shipments (various states: pending, in_transit, delivered)
  - Realistic scenarios for testing action queue

### 3. Supabase Client Libraries

- [x] **Browser Client** (`apps/web/src/lib/supabase/client.ts`)
  - Client-side Supabase client using `@supabase/ssr`
  - Environment variable validation
  - TypeScript typed with Database interface

- [x] **Server Client** (`apps/web/src/lib/supabase/server.ts`)
  - Server-side client for App Router
  - Cookie-based session management
  - Helper functions: `getCurrentUser()`, `getSession()`, `signOut()`, `refreshSession()`

- [x] **TypeScript Types** (`apps/web/src/lib/supabase/types.ts`)
  - Complete type definitions for all tables
  - ENUM types (6 total)
  - Interface definitions for Row, Insert, Update operations
  - Database type for RPC functions

### 4. Documentation

- [x] **Data Model** (`docs/dm/020_DATA_MODEL.md`)
  - Complete schema documentation
  - 9 tables with field descriptions
  - 6 ENUM types
  - 40+ indexes
  - Computed columns
  - Relationships diagram
  - Data integrity rules
  - Helper functions

- [x] **RLS Policies** (`docs/dm/030_RLS_POLICIES.md`)
  - Security model explanation
  - Helper function documentation
  - Policy details for all 9 tables
  - Service role usage patterns
  - Testing procedures
  - Performance considerations

---

## Database Schema

### Core Tables (9 total)

**Organizations** - Internal (Stone Forest) and customer organizations
```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY,
  name VARCHAR(255),
  type VARCHAR(20) CHECK (type IN ('internal', 'customer')),
  contact_email VARCHAR(255),
  contact_phone VARCHAR(50),
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**Users** - Staff and customer contacts linked to Supabase Auth
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  organization_id UUID REFERENCES organizations,
  email VARCHAR(255) UNIQUE,
  name VARCHAR(255),
  role VARCHAR(20) CHECK (role IN ('admin', 'staff', 'customer')),
  auth_user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**Projects** - Customer work (print jobs, design projects)
```sql
CREATE TABLE projects (
  id UUID PRIMARY KEY,
  organization_id UUID REFERENCES organizations,
  name VARCHAR(255),
  description TEXT,
  status VARCHAR(20) CHECK (status IN ('active', 'on_hold', 'completed', 'cancelled')),
  created_by UUID REFERENCES users,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**Invoices** - Payment tracking with deposit support
```sql
CREATE TABLE invoices (
  id UUID PRIMARY KEY,
  project_id UUID REFERENCES projects,
  organization_id UUID REFERENCES organizations,
  invoice_number VARCHAR(50) UNIQUE,
  issue_date DATE,
  due_date DATE,
  amount_subtotal INTEGER,  -- in cents
  amount_tax INTEGER,
  amount_total INTEGER,
  amount_paid INTEGER,
  balance_due INTEGER GENERATED ALWAYS AS (amount_total - amount_paid) STORED,
  deposit_required BOOLEAN,
  deposit_amount INTEGER,
  deposit_paid BOOLEAN,
  deposit_paid_at TIMESTAMPTZ,
  status invoice_status,  -- draft, sent, paid, overdue, cancelled
  notes TEXT,
  created_by UUID REFERENCES users,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**Invoice Events** - Audit log for invoice lifecycle
```sql
CREATE TABLE invoice_events (
  id UUID PRIMARY KEY,
  invoice_id UUID REFERENCES invoices,
  event_type invoice_event_type,
  event_data JSONB,
  triggered_by UUID REFERENCES users,
  triggered_by_system VARCHAR(50),
  created_at TIMESTAMPTZ
);
```

**File Assets** - Proofs, artwork, and attachments with version control
```sql
CREATE TABLE file_assets (
  id UUID PRIMARY KEY,
  project_id UUID REFERENCES projects,
  organization_id UUID REFERENCES organizations,
  file_name VARCHAR(255),
  file_size_bytes INTEGER,
  file_type file_type,  -- proof, artwork, reference, attachment
  mime_type VARCHAR(100),
  storage_bucket VARCHAR(100),
  storage_path VARCHAR(500),
  version_number INTEGER,
  is_current_version BOOLEAN,
  parent_file_id UUID REFERENCES file_assets,
  approval_status approval_status,  -- pending, approved, rejected, revision, final
  approved_by UUID REFERENCES users,
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  uploaded_by UUID REFERENCES users,
  notes TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**Approval Events** - Audit log for proof approval workflow
```sql
CREATE TABLE approval_events (
  id UUID PRIMARY KEY,
  file_asset_id UUID REFERENCES file_assets,
  event_type VARCHAR(50),
  event_data JSONB,
  triggered_by UUID REFERENCES users,
  triggered_by_system VARCHAR(50),
  notification_sent BOOLEAN,
  notification_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
);
```

**Shipments** - Carrier tracking and delivery management
```sql
CREATE TABLE shipments (
  id UUID PRIMARY KEY,
  project_id UUID REFERENCES projects,
  organization_id UUID REFERENCES organizations,
  shipment_number VARCHAR(50) UNIQUE,
  carrier shipping_carrier,  -- usps, ups, fedex, dhl, other, hand_delivery
  tracking_number VARCHAR(100),
  tracking_url VARCHAR(500),
  status shipment_status,  -- pending, preparing, shipped, in_transit, out_for_delivery, delivered, failed, cancelled, returned
  status_updated_at TIMESTAMPTZ,
  expected_ship_date DATE,
  actual_ship_date DATE,
  expected_delivery_date DATE,
  actual_delivery_date DATE,
  ship_from_address JSONB,
  ship_to_address JSONB,
  package_count INTEGER,
  weight_lbs DECIMAL(10, 2),
  dimensions_inches VARCHAR(50),
  shipping_cost_cents INTEGER,
  insurance_cost_cents INTEGER,
  notes TEXT,
  internal_notes TEXT,
  created_by UUID REFERENCES users,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**Shipment Events** - Tracking updates and status changes
```sql
CREATE TABLE shipment_events (
  id UUID PRIMARY KEY,
  shipment_id UUID REFERENCES shipments,
  event_type VARCHAR(50),
  event_data JSONB,
  old_status shipment_status,
  new_status shipment_status,
  location VARCHAR(255),
  location_coordinates POINT,
  triggered_by UUID REFERENCES users,
  triggered_by_system VARCHAR(50),
  notification_sent BOOLEAN,
  notification_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
);
```

### ENUM Types (6 total)

1. **invoice_status** - `draft`, `sent`, `paid`, `overdue`, `cancelled`
2. **invoice_event_type** - `created`, `sent`, `viewed`, `payment_received`, `payment_partial`, `deposit_received`, `reminder_7day`, `reminder_due`, `reminder_overdue`, `marked_overdue`, `cancelled`
3. **file_type** - `proof`, `artwork`, `reference`, `attachment`
4. **approval_status** - `pending`, `approved`, `rejected`, `revision`, `final`
5. **shipment_status** - `pending`, `preparing`, `shipped`, `in_transit`, `out_for_delivery`, `delivered`, `failed`, `cancelled`, `returned`
6. **shipping_carrier** - `usps`, `ups`, `fedex`, `dhl`, `other`, `hand_delivery`

### Indexes (40+)

**Performance Optimizations:**
- Foreign key indexes on all relationships
- Status indexes for filtering workflows
- Date indexes for time-based queries
- Partial indexes for current versions
- Descending indexes for chronological sorting
- Unique indexes for business identifiers

**Key Indexes:**
```sql
-- Critical for RLS performance
CREATE INDEX idx_users_auth ON users(auth_user_id);
CREATE INDEX idx_users_organization ON users(organization_id);

-- Critical for invoice workflows
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_balance_due ON invoices(balance_due);
CREATE INDEX idx_invoices_status ON invoices(status);

-- Critical for proof workflows
CREATE INDEX idx_file_assets_approval_status ON file_assets(approval_status);
CREATE INDEX idx_file_assets_is_current ON file_assets(is_current_version) WHERE is_current_version = true;

-- Critical for shipment tracking
CREATE INDEX idx_shipments_tracking_number ON shipments(tracking_number);
CREATE INDEX idx_shipments_expected_delivery ON shipments(expected_delivery_date);
```

### Computed Columns

**invoices.balance_due** - Remaining balance (amount_total - amount_paid)
```sql
ALTER TABLE invoices ADD COLUMN balance_due INTEGER
  GENERATED ALWAYS AS (amount_total - amount_paid) STORED;
```

Stored computed column for efficient querying without recalculation.

### Trigger Functions

**update_updated_at_column()** - Auto-updates updated_at timestamp
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Applied to all tables with updated_at columns.

### Action Queue View

**internal_action_queue** - Unified view of actionable items for staff dashboard

**Action Types:**
1. `deposit_unpaid` (Priority 1) - Invoices requiring deposit payment
2. `invoice_due_soon` (Priority 2) - Invoices due within 7 days
3. `invoice_overdue` (Priority 1) - Past due invoices
4. `proof_pending` (Priority 2) - Proofs awaiting approval >2 days
5. `shipment_no_tracking` (Priority 2) - Shipments missing tracking numbers
6. `shipment_eta_risk` (Priority 2) - Deliveries within 2 days
7. `shipment_overdue` (Priority 1) - Missed delivery dates

**View Columns:**
- `action_type`, `priority`, `record_id`, `identifier`
- `title`, `description`
- `organization_id`, `customer_name`
- `project_id`, `project_name`
- `created_date`, `due_date`, `days_open`
- `metadata` (JSONB with context)

---

## Technical Implementation

### PostgreSQL Patterns

**Integer Cents Pattern** - All currency stored as integers
```sql
amount_total INTEGER  -- $100.00 = 10000
```

Avoids floating-point precision issues in financial calculations.

**JSONB for Flexibility** - Semi-structured data
```sql
event_data JSONB  -- Flexible metadata per event type
ship_to_address JSONB  -- Address structure without rigid schema
```

Queryable yet flexible for evolving requirements.

**Computed Columns** - Derived values stored for performance
```sql
balance_due INTEGER GENERATED ALWAYS AS (amount_total - amount_paid) STORED
```

Indexed for fast filtering without recalculation overhead.

**Version Control Pattern** - File asset versioning
```sql
version_number INTEGER
is_current_version BOOLEAN
parent_file_id UUID REFERENCES file_assets(id)
```

Maintains full history while marking current version.

**Audit Trail Pattern** - Event tables for all state changes
```sql
-- Separate event tables: invoice_events, approval_events, shipment_events
-- Append-only (no UPDATE/DELETE policies)
-- JSONB event_data for flexible context
```

### RLS Security Model

**Data Isolation Strategy:**

1. **Customers see only their own data**
```sql
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
)
```

2. **Internal staff see all data**
```sql
USING (auth.is_internal_user())
```

3. **Draft protection** - Customers cannot see draft invoices
```sql
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND status != 'draft'
)
```

4. **Proof approval access** - Customers can approve/reject proofs
```sql
-- Limited UPDATE access for approval_status only
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND file_type = 'proof'
)
```

**Helper Functions:**
- All marked `STABLE` for query-level caching
- `SECURITY DEFINER` to access public schema
- Use indexed columns for fast lookups
- `LIMIT 1` to prevent unnecessary scanning

**Performance:**
- organization_id indexed on all tables
- Helper functions avoid complex inline JOINs
- Partial indexes for filtered columns

---

## Integration Points

### Supabase Client Libraries

**Browser Client** (Client Components)
```typescript
import { createClient } from '@/lib/supabase/client'

const supabase = createClient()
const { data: invoices } = await supabase
  .from('invoices')
  .select('*, projects(*), organizations(*)')
  .eq('organization_id', user.organization_id)
```

**Server Client** (Server Components, Route Handlers)
```typescript
import { createServerClient } from '@/lib/supabase/server'

const supabase = await createServerClient()
const { data: user } = await supabase.auth.getUser()
```

**Helper Functions**
```typescript
import { getCurrentUser, getSession, signOut } from '@/lib/supabase/server'

const user = await getCurrentUser()
const session = await getSession()
await signOut()
```

### TypeScript Type Definitions

**Full type safety for all database operations:**

```typescript
import type {
  Invoice,
  InvoiceWithRelations,
  CreateInvoiceInput,
  UpdateInvoiceInput,
  Database
} from '@/lib/supabase/types'

// Typed queries
const { data } = await supabase
  .from('invoices')
  .select<'*', InvoiceWithRelations>('*, projects(*), organizations(*)')
```

### Environment Variables

**Required for Supabase connection:**

```env
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx  # For n8n workflows (server-side only)
```

**Service Role Usage:**
- n8n workflows (automated reminders, status updates)
- Cron jobs (mark invoices overdue)
- Carrier webhooks (shipment tracking)
- Payment webhooks (Stripe integration)

**⚠️ Security:** Never expose service role key to client-side code.

---

## Testing Checklist

### Database Setup
- [x] Migrations run successfully in order
- [x] All tables created with correct schema
- [x] All indexes created
- [x] All ENUM types defined
- [x] All triggers attached
- [x] Computed columns working

### RLS Policies
- [ ] Internal users can see all data
- [ ] Customers can only see their own data
- [ ] Customers cannot see draft invoices
- [ ] Customers can approve/reject proofs
- [ ] Service role bypasses RLS correctly

### Helper Functions
- [ ] `auth.user_role()` returns correct role
- [ ] `auth.user_organization_id()` returns correct org
- [ ] `auth.is_internal_user()` works for staff/customers
- [ ] `auth.is_admin()` works correctly
- [ ] `auth.is_staff()` works correctly

### Seed Data
- [x] Organizations inserted correctly
- [x] Users linked to organizations
- [x] Projects created for all customers
- [x] Invoices in various states
- [x] Invoice events logged
- [x] File assets with version history
- [x] Shipments with tracking data
- [x] Action queue view populated

### Client Libraries
- [ ] Browser client connects successfully
- [ ] Server client uses cookies correctly
- [ ] Type definitions match schema
- [ ] Environment variables validated
- [ ] Auth helpers work in Server Components

### Documentation
- [x] Data model fully documented
- [x] RLS policies explained
- [x] Field descriptions complete
- [x] Relationships documented
- [x] Integrity rules defined

---

## Known Limitations

### Sprint 002A Scope

1. **No frontend integration yet** - Schema ready, UI not connected (Sprint 002B)
2. **Mock data still in use** - Frontend still using `invoices.json` mock data
3. **n8n workflows not implemented** - Database ready, automation not built
4. **No Supabase Auth users** - Seed data has `auth_user_id = NULL`
5. **No file uploads** - Storage bucket configured but not integrated
6. **No payment processing** - Schema ready for Stripe but not integrated
7. **No carrier webhooks** - Tracking table ready but no webhook handlers

### Implementation Notes

**Authentication:**
- Users table ready but no Supabase Auth users created yet
- `auth_user_id` field exists but all NULL in seed data
- RLS policies depend on auth - will work when Auth is integrated

**Storage:**
- `file_assets` table references Supabase Storage paths
- Storage bucket 'file-assets' needs to be created in Supabase dashboard
- RLS policies needed for storage bucket access

**n8n Integration:**
- Service role key needed for automated workflows
- Event logging pattern established but no workflows exist yet
- Invoice reminder workflows documented but not implemented

---

## Next Steps

### Immediate (Sprint 002B)

**Connect Frontend to Supabase:**
1. Replace mock data with real Supabase queries
2. Implement Supabase Auth (login/logout)
3. Update customer dashboard to use real data
4. Update invoices page to use real data
5. Update projects page to use real data
6. Test RLS policies with real users

### Sprint 003A: Proof Approval UI

**Customer Proof Workflow:**
1. View proofs page (list all proofs for customer)
2. Proof detail modal (view PDF, approve/reject)
3. Approval action (update approval_status)
4. Email notification to staff on approval/rejection
5. Version history display
6. n8n workflow for proof upload notifications

### Sprint 003B: Shipment Tracking UI

**Customer Tracking:**
1. View shipments page (list all shipments)
2. Shipment detail modal (tracking timeline)
3. Carrier tracking integration (UPS, FedEx, USPS APIs)
4. Email notifications on status changes
5. n8n workflow for tracking updates

### Sprint 004: Internal Dashboard

**Staff Action Queue:**
1. Dashboard showing action_queue view
2. Filter by action type and priority
3. Quick actions (mark paid, send reminder)
4. Customer lookup and details
5. Invoice management (create, edit, send)
6. Proof upload and management
7. Shipment tracking updates

### Future Enhancements

**Technical Debt:**
1. Add integration tests for RLS policies
2. Performance testing with large datasets
3. Backup and disaster recovery procedures
4. Database monitoring and alerting

**Features:**
1. PDF invoice generation
2. Stripe payment integration
3. Email templates (SendGrid)
4. Automated invoice reminders
5. Automated overdue marking
6. Real-time notifications (websockets)

---

## Success Metrics

### Database Performance

**Target metrics:**
- Query response time: <100ms for simple queries
- RLS overhead: <20ms additional latency
- Index usage: >90% of queries using indexes
- Connection pool: <50% utilization

### Data Integrity

**Validation:**
- Zero orphaned records (all foreign keys valid)
- Zero negative amounts (CHECK constraints working)
- Zero invalid enum values (ENUM types enforced)
- 100% audit trail coverage (all events logged)

### Security

**Compliance:**
- 100% RLS policy coverage (all tables protected)
- Zero customer data leaks (isolation verified)
- Zero draft invoice visibility (protection verified)
- Service role usage audited and documented

---

## Files Changed

### Database (Supabase)

**Migrations:**
- `/supabase/migrations/20260118000001_create_profiles_and_customers.sql` (created)
- `/supabase/migrations/20260118000002_create_projects.sql` (created)
- `/supabase/migrations/20260118000003_create_invoices.sql` (created)
- `/supabase/migrations/20260118000004_create_proofs.sql` (created)
- `/supabase/migrations/20260118000005_create_shipments.sql` (created)
- `/supabase/migrations/20260118000006_create_rls_helpers.sql` (created)
- `/supabase/migrations/20260118000007_enable_rls_policies.sql` (created)
- `/supabase/migrations/20260118000008_create_action_queue_view.sql` (created)

**Seed Data:**
- `/supabase/seed.sql` (created)

### Frontend (Next.js)

**Supabase Client Libraries:**
- `/apps/web/src/lib/supabase/client.ts` (created)
- `/apps/web/src/lib/supabase/server.ts` (created)
- `/apps/web/src/lib/supabase/types.ts` (created)

### Documentation

**Architecture Docs:**
- `/docs/dm/020_DATA_MODEL.md` (created)
- `/docs/dm/030_RLS_POLICIES.md` (created)

**Deliverables:**
- `/docs/deliverables/sprint_002a_supabase_foundation.md` (this file)

---

## Deployment Notes

### Supabase Setup

**Project Configuration:**
1. Create Supabase project (or use existing)
2. Copy `.env.example` to `.env.local`
3. Set `NEXT_PUBLIC_SUPABASE_URL` from project settings
4. Set `NEXT_PUBLIC_SUPABASE_ANON_KEY` from project settings
5. Set `SUPABASE_SERVICE_ROLE_KEY` (server-side only, DO NOT commit)

**Run Migrations:**
```bash
# Option 1: Supabase CLI (recommended)
supabase db push

# Option 2: SQL Editor in Supabase Dashboard
# Copy/paste each migration file in order (001 → 008)
```

**Load Seed Data:**
```bash
# Option 1: Supabase CLI
supabase db reset --linked

# Option 2: SQL Editor
# Copy/paste seed.sql into SQL Editor and run
```

**Verify Setup:**
```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
-- Should return 9 tables + 1 view

-- Check RLS enabled
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public';
-- All should have rowsecurity = true

-- Check seed data
SELECT
  (SELECT COUNT(*) FROM organizations) as orgs,
  (SELECT COUNT(*) FROM users) as users,
  (SELECT COUNT(*) FROM projects) as projects,
  (SELECT COUNT(*) FROM invoices) as invoices,
  (SELECT COUNT(*) FROM file_assets) as files,
  (SELECT COUNT(*) FROM shipments) as shipments;
-- Should show: 4 orgs, 8 users, 9 projects, 9 invoices, 8 files, 7 shipments
```

### Storage Configuration

**Create Storage Bucket:**
1. Go to Supabase Dashboard → Storage
2. Create bucket: `file-assets`
3. Set as **private** (use RLS)
4. Configure RLS policies for bucket:

```sql
-- Customers can view files for their organization
CREATE POLICY "Customers can view their files"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'file-assets'
  AND auth.is_authenticated()
  AND (
    auth.is_internal_user()
    OR
    (
      storage.foldername(name)[1] IN (
        SELECT id::text FROM projects
        WHERE organization_id = auth.user_organization_id()
      )
    )
  )
);

-- Internal users can upload files
CREATE POLICY "Internal users can upload files"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'file-assets'
  AND auth.is_internal_user()
);
```

### Environment Variables (Production)

**Vercel/Production:**
```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx  # DO NOT expose to client

# Email (future)
SENDGRID_API_KEY=xxx
SENDGRID_FROM_EMAIL=invoices@stoneforest.com

# Payment (future)
STRIPE_PUBLIC_KEY=xxx
STRIPE_SECRET_KEY=xxx

# n8n (future)
N8N_WEBHOOK_URL=xxx
N8N_API_KEY=xxx
```

---

## Sign-off

**Developer**: Claude Code
**Date**: 2026-01-18
**Sprint**: 002A - Supabase Foundation
**Status**: ✅ Ready for Sprint 002B (Frontend Integration)

**Summary**: Complete database foundation established with 9 tables, 6 ENUM types, 40+ indexes, comprehensive RLS policies, seed data, TypeScript types, and Supabase client libraries. Frontend integration ready to begin in Sprint 002B.
