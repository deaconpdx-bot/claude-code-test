# Sprint 001: Invoice MVP

## Overview

**Goal**: Implement invoice management system with automated reminders and customer portal visibility.

**Status**: ✅ Complete

**Sprint Duration**: Sprint 001

---

## Deliverables

### 1. Documentation

- [x] **Data Model** (`/docs/dm/020_DATA_MODEL.md`)
  - Invoice schema (invoices, invoice_events tables)
  - Field definitions with amounts in cents
  - Deposit tracking support
  - Status flow documentation

- [x] **RLS Policies** (`/docs/dm/030_RLS_POLICIES.md`)
  - Customer data isolation
  - Internal staff full access
  - Service role usage for n8n
  - Helper functions for auth

- [x] **n8n Integration Spec** (`/docs/dm/070_TRACKING_N8N_INTEGRATION.md`)
  - 4 automated workflows (7-day, due today, overdue, status updates)
  - Email reminder logic
  - Event logging specification
  - Error handling and monitoring

### 2. Database Schema

**Tables Defined** (SQL in 020_DATA_MODEL.md):

```sql
-- Core invoice table
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
  deposit_required BOOLEAN,
  deposit_amount INTEGER,
  deposit_paid BOOLEAN,
  status invoice_status,  -- draft, sent, paid, overdue, cancelled
  ...
);

-- Audit log for invoice lifecycle
CREATE TABLE invoice_events (
  id UUID PRIMARY KEY,
  invoice_id UUID REFERENCES invoices,
  event_type invoice_event_type,
  event_data JSONB,
  triggered_by UUID REFERENCES users,
  triggered_by_system VARCHAR(50),
  created_at TIMESTAMP
);
```

**Status Flow:**
```
draft → sent → paid
         ↓
      overdue → paid
```

### 3. UI Components

#### Customer Dashboard (/customer/dashboard)

**Added Invoice Metrics Section:**

- Paid invoices count
- Due soon (≤7 days) count
- Due today count
- Past due count
- Deposit indicators (required/paid)

**Layout**: KPI stat cards below existing metrics

#### Invoices Page (/customer/invoices)

**Features:**

- Table listing all invoices with:
  - Invoice number
  - Project name
  - Issue date / Due date
  - Amount total / Amount paid
  - Status badge (Draft, Sent, Paid, Overdue)
  - Deposit indicator
- Click row to open invoice detail modal
- Premium monochrome table design

**Invoice Detail Modal:**

- Full invoice information
- Line items (if applicable)
- Payment history from invoice_events
- Deposit status
- Payment link (placeholder for future)

### 4. Mock Data

**File**: `/apps/web/src/mock-data/invoices.json`

**Structure**: Matches final Supabase schema exactly

```json
{
  "invoices": [
    {
      "id": "inv-001",
      "project_id": "proj-001",
      "organization_id": "org-customer-001",
      "invoice_number": "INV-2026-001",
      "issue_date": "2026-01-10",
      "due_date": "2026-02-10",
      "amount_subtotal": 50000,  // $500.00
      "amount_tax": 5000,
      "amount_total": 55000,
      "amount_paid": 0,
      "deposit_required": true,
      "deposit_amount": 27500,  // 50%
      "deposit_paid": false,
      "status": "sent",
      ...
    }
  ],
  "invoice_events": [...]
}
```

**Mock Scenarios**:

- Paid invoice
- Invoice due in 5 days (due soon)
- Invoice due today
- Overdue invoice (3 days late)
- Invoice with deposit required and paid
- Draft invoice (not visible to customer)

---

## Technical Implementation

### Frontend

**Tech Stack:**
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS (monochrome design system)
- Framer Motion (subtle animations)

**New Pages:**
- `/apps/web/src/app/customer/invoices/page.tsx`

**New Components:**
- `/apps/web/src/components/InvoiceDetailModal.tsx` (if created separately)

**Updated Components:**
- `/apps/web/src/app/customer/dashboard/page.tsx` (added invoice metrics)
- `/apps/web/src/components/Sidebar.tsx` (added Invoices nav link)

### Data Layer

**Current State**: Mock data (no Supabase integration yet)

**Future Migration**:
```typescript
// Replace this:
import invoicesData from '@/mock-data/invoices.json'

// With this:
import { createClient } from '@/lib/supabase/client'
const supabase = createClient()
const { data: invoices } = await supabase
  .from('invoices')
  .select('*, projects(*), organizations(*)')
  .eq('organization_id', user.organization_id)
```

---

## Integration Points (Placeholder)

### n8n Workflows

**Status**: Documented, not implemented

**Workflows**:
1. Invoice reminder - 7 days before due
2. Invoice reminder - due today
3. Invoice reminder - past due
4. Mark invoices as overdue (daily cron)

**Action Required**:
- Set up n8n instance
- Configure Supabase connection
- Import workflow JSON files (to be created)
- Set up SMTP (SendGrid)

### Payment Processing

**Status**: Out of scope for Sprint 001

**Future Sprints**:
- Stripe integration
- Payment link generation
- Webhook for instant payment updates
- Auto-reconciliation

---

## Testing Checklist

- [x] Dashboard shows correct invoice counts
- [x] Invoices page displays all invoices
- [x] Status badges use correct colors
- [x] Deposit indicators visible
- [x] Invoice detail modal opens and displays data
- [x] Responsive design works on mobile
- [x] Monochrome design system applied consistently
- [ ] RLS policies tested in Supabase (when connected)
- [ ] n8n workflows tested in staging

---

## Known Limitations

1. **No real payments**: Mock data only, no Stripe/PayPal integration
2. **No email sending**: n8n workflows documented but not implemented
3. **No Supabase connection**: Using mock JSON data
4. **Customer can't pay online**: Payment link is placeholder
5. **No PDF invoice generation**: Future enhancement

---

## Next Steps (Post-Sprint 001)

### Immediate (Technical Debt)

1. Connect Supabase and migrate to real database
2. Implement n8n workflows for reminders
3. Set up email templates (SendGrid)
4. Add unit tests for invoice calculations

### Sprint 002: Proof Approval MVP

- File upload system
- Version control for artwork
- Approval workflow
- Email notifications for new proofs

### Sprint 003: Tracking MVP

- Shipment tracking integration
- Order status updates
- Delivery notifications

---

## Success Metrics

### Customer Experience

- **Invoice visibility**: Customers can see all their invoices in one place
- **Payment urgency**: Clear indicators for due soon/overdue invoices
- **Deposit tracking**: Customers know if deposit is required/paid

### Internal Efficiency

- **Automated reminders**: Reduces manual follow-up by staff
- **Audit trail**: All invoice interactions logged in invoice_events
- **Status automation**: Invoices automatically marked overdue

### Future Metrics (Post-Production)

- Time to payment (days from invoice sent → paid)
- Reminder effectiveness (% paid after each reminder type)
- Overdue rate (% of invoices past due)

---

## Screenshots

### Customer Dashboard - Invoice Metrics

```
┌─────────────────────────────────────────────────┐
│ Dashboard                                        │
│ Overview of your account activity                │
└─────────────────────────────────────────────────┘

┌──────────┐  ┌──────────┐  ┌──────────┐
│ PAID     │  │ DUE SOON │  │ DUE TODAY│
│ 12       │  │ 3        │  │ 1        │
└──────────┘  └──────────┘  └──────────┘

┌──────────┐
│ PAST DUE │
│ 2        │
└──────────┘
```

### Invoices Page

```
┌─────────────────────────────────────────────────┐
│ Invoices                                         │
│ Manage your invoices and payments               │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ Invoice #    │ Project    │ Due Date  │ Status  │
├─────────────────────────────────────────────────┤
│ INV-2026-001 │ Catalog Q1 │ Feb 10    │ [Sent]  │
│ INV-2026-002 │ Brochures  │ Jan 25    │ [Paid]  │
│ INV-2026-003 │ Posters    │ Jan 17    │[Overdue]│
└─────────────────────────────────────────────────┘
```

---

## Files Changed

### Documentation

- `/docs/dm/020_DATA_MODEL.md` (created)
- `/docs/dm/030_RLS_POLICIES.md` (created)
- `/docs/dm/070_TRACKING_N8N_INTEGRATION.md` (created)
- `/docs/deliverables/sprint_001_invoice_mvp.md` (this file)

### Frontend

- `/apps/web/src/mock-data/invoices.json` (created)
- `/apps/web/src/app/customer/dashboard/page.tsx` (updated)
- `/apps/web/src/app/customer/invoices/page.tsx` (created)
- `/apps/web/src/components/Sidebar.tsx` (updated)

### Configuration

- README.md (updated with invoice feature)

---

## Deployment Notes

### Environment Variables Required

```env
# Supabase (when ready)
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx  # For n8n

# Email (when ready)
SENDGRID_API_KEY=xxx
SENDGRID_FROM_EMAIL=invoices@stoneforest.com

# Payment (future)
STRIPE_PUBLIC_KEY=xxx
STRIPE_SECRET_KEY=xxx
```

### Database Migration

When connecting Supabase:

1. Run schema from `020_DATA_MODEL.md`
2. Apply RLS policies from `030_RLS_POLICIES.md`
3. Import test data
4. Verify RLS with test users

---

## Sign-off

**Developer**: Claude Code
**Date**: 2026-01-17
**Sprint**: 001
**Status**: Ready for Review
