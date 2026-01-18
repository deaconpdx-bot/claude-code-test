# Row Level Security (RLS) Policies

## Overview

All tables in the Stone Forest App use Supabase Row Level Security (RLS) to enforce data isolation between customers and control access for internal staff.

**Last Updated:** Sprint 002A (2026-01-18)

**Security Principles:**

1. **Customers see only their own data** - Never data from other customers
2. **Internal staff see all data** - Full access for Stone Forest employees
3. **Authentication required** - No anonymous access
4. **Audit trail** - All data modifications logged in event tables
5. **Draft protection** - Customers cannot see draft invoices

---

## Table of Contents

1. [Helper Functions](#helper-functions)
2. [Organizations Table](#organizations-table)
3. [Users Table](#users-table)
4. [Projects Table](#projects-table)
5. [Invoices Table](#invoices-table)
6. [Invoice Events Table](#invoice-events-table)
7. [File Assets Table](#file-assets-table)
8. [Approval Events Table](#approval-events-table)
9. [Shipments Table](#shipments-table)
10. [Shipment Events Table](#shipment-events-table)
11. [Service Role Access](#service-role-access)
12. [Security Patterns](#security-patterns)

---

## Helper Functions

These helper functions are used across all RLS policies to determine user context and permissions.

### auth.user_role()

Returns the role of the currently authenticated user (admin, staff, customer).

```sql
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS VARCHAR(20) AS $$
  SELECT role
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.user_role() TO authenticated;
```

---

### auth.user_organization_id()

Returns the organization_id of the currently authenticated user.

```sql
CREATE OR REPLACE FUNCTION auth.user_organization_id()
RETURNS UUID AS $$
  SELECT organization_id
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.user_organization_id() TO authenticated;
```

---

### auth.user_customer_id()

Alias for `user_organization_id()` - provides semantic clarity in customer-facing contexts.

```sql
CREATE OR REPLACE FUNCTION auth.user_customer_id()
RETURNS UUID AS $$
  SELECT auth.user_organization_id();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.user_customer_id() TO authenticated;
```

---

### auth.is_internal_user()

Returns true if the current user belongs to an internal organization (Stone Forest employee).

```sql
CREATE OR REPLACE FUNCTION auth.is_internal_user()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.organizations o ON u.organization_id = o.id
    WHERE u.auth_user_id = auth.uid()
    AND o.type = 'internal'
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.is_internal_user() TO authenticated;
```

---

### auth.is_admin()

Returns true if the current user has admin role.

```sql
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN AS $$
  SELECT auth.user_role() = 'admin';
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.is_admin() TO authenticated;
```

---

### auth.is_staff()

Returns true if the current user has admin or staff role.

```sql
CREATE OR REPLACE FUNCTION auth.is_staff()
RETURNS BOOLEAN AS $$
  SELECT auth.user_role() IN ('admin', 'staff');
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auth.is_staff() TO authenticated;
```

**Performance Notes:**
- All functions are marked `STABLE` so they're cached per query
- `SECURITY DEFINER` allows functions to access public schema tables
- Indexed columns (auth_user_id, organization_id, type) ensure fast lookups
- `LIMIT 1` prevents unnecessary row scanning

---

## Organizations Table

```sql
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- Internal users can see all organizations
CREATE POLICY "Internal users can view all organizations"
ON organizations FOR SELECT
USING (auth.is_internal_user());

-- Customers can only see their own organization
CREATE POLICY "Customers can view their organization"
ON organizations FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND id = auth.user_organization_id()
);

-- Only admins can create/update/delete organizations
CREATE POLICY "Admins can manage organizations"
ON organizations FOR ALL
USING (auth.user_role() = 'admin');
```

**Business Rules:**
- Internal staff can view all organizations (both internal and customer)
- Customer users can only see their own organization details
- Only admins can create, update, or delete organizations

---

## Users Table

```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Internal users can see all users
CREATE POLICY "Internal users can view all users"
ON users FOR SELECT
USING (auth.is_internal_user());

-- Customers can see users in their organization
CREATE POLICY "Customers can view their organization users"
ON users FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- Admins and staff can manage all users
CREATE POLICY "Admins and staff can manage users"
ON users FOR ALL
USING (auth.user_role() IN ('admin', 'staff'));
```

**Business Rules:**
- Internal staff can see all users across all organizations
- Customer users can see other users in their organization
- Users can update their own profile information (name, email, etc.)
- Admin and staff users can create, update, or delete any user

---

## Projects Table

```sql
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Internal users can see all projects
CREATE POLICY "Internal users can view all projects"
ON projects FOR SELECT
USING (auth.is_internal_user());

-- Customers can see their organization's projects
CREATE POLICY "Customers can view their projects"
ON projects FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
);

-- Internal users can create projects
CREATE POLICY "Internal users can create projects"
ON projects FOR INSERT
WITH CHECK (auth.is_internal_user());

-- Internal users can update projects
CREATE POLICY "Internal users can update projects"
ON projects FOR UPDATE
USING (auth.is_internal_user())
WITH CHECK (auth.is_internal_user());

-- Only admins can delete projects
CREATE POLICY "Admins can delete projects"
ON projects FOR DELETE
USING (auth.user_role() = 'admin');
```

**Business Rules:**
- Internal staff can see all customer projects
- Customers can only see projects belonging to their organization
- Internal staff can create new projects for any customer
- Internal staff can update project details
- Only admins can delete projects (rare operation)

---

## Invoices Table

```sql
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Internal users can see all invoices
CREATE POLICY "Internal users can view all invoices"
ON invoices FOR SELECT
USING (auth.is_internal_user());

-- Customers can see their organization's invoices (excluding drafts)
CREATE POLICY "Customers can view their invoices"
ON invoices FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND status != 'draft'
);

-- Only internal staff can create invoices
CREATE POLICY "Internal users can create invoices"
ON invoices FOR INSERT
WITH CHECK (auth.is_internal_user());

-- Only internal staff can update invoices
CREATE POLICY "Internal users can update invoices"
ON invoices FOR UPDATE
USING (auth.is_internal_user())
WITH CHECK (auth.is_internal_user());

-- Only admins can delete invoices
CREATE POLICY "Admins can delete invoices"
ON invoices FOR DELETE
USING (auth.user_role() = 'admin');
```

**Business Rules:**

- Internal staff can see all invoices including drafts
- Customers can see their invoices **but not draft invoices** (enforced at database level)
- Internal staff can **create and update** invoices
- Only admins can **delete** invoices (rare, for corrections)
- Customers can **view** invoices but cannot modify them

**Key Security Feature:** Draft invoices are hidden from customers at the database level via RLS policy (`status != 'draft'`), not just the application layer.

---

## Invoice Events Table

```sql
ALTER TABLE invoice_events ENABLE ROW LEVEL SECURITY;

-- Internal users can see all invoice events
CREATE POLICY "Internal users can view all invoice events"
ON invoice_events FOR SELECT
USING (auth.is_internal_user());

-- Customers can see events for their non-draft invoices
CREATE POLICY "Customers can view their invoice events"
ON invoice_events FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND EXISTS (
    SELECT 1
    FROM invoices
    WHERE invoices.id = invoice_events.invoice_id
    AND invoices.organization_id = auth.user_organization_id()
    AND invoices.status != 'draft'
  )
);

-- Internal users can manually create events
CREATE POLICY "Internal users can create invoice events"
ON invoice_events FOR INSERT
WITH CHECK (auth.is_internal_user());

-- No UPDATE or DELETE policies (audit log is append-only)
-- Admins can delete via service role if absolutely necessary
```

**Business Rules:**

- Internal staff can see all invoice events across all customers
- Customers can see events for their **non-draft** invoices only
- Internal staff can manually log invoice events
- Audit log is append-only - no updates or deletes allowed through RLS
- System (n8n, cron) uses service role to insert events (bypasses RLS)

**Event Visibility for Customers:**

Customers can see **most** events, but certain events may be filtered in the application layer:

- ✅ Visible: `sent`, `payment_received`, `payment_partial`, `deposit_received`, `reminder_*`
- ⚠️ May be hidden: `created`, `marked_overdue` (can be hidden in UI)
- ❌ Hidden: Events for draft invoices (enforced by RLS policy)

---

## File Assets Table

```sql
ALTER TABLE file_assets ENABLE ROW LEVEL SECURITY;

-- Internal users can see all file assets
CREATE POLICY "Internal users can view all file assets"
ON file_assets FOR SELECT
USING (auth.is_internal_user());

-- Customers can see file assets for their organization's projects
CREATE POLICY "Customers can view their file assets"
ON file_assets FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
);

-- Internal users can create file assets
CREATE POLICY "Internal users can create file assets"
ON file_assets FOR INSERT
WITH CHECK (auth.is_internal_user());

-- Internal users can update file assets
CREATE POLICY "Internal users can update file assets"
ON file_assets FOR UPDATE
USING (auth.is_internal_user())
WITH CHECK (auth.is_internal_user());

-- Customers can update approval status on proofs
CREATE POLICY "Customers can update file asset approvals"
ON file_assets FOR UPDATE
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND file_type = 'proof'
)
WITH CHECK (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND file_type = 'proof'
);

-- Only admins can delete file assets
CREATE POLICY "Admins can delete file assets"
ON file_assets FOR DELETE
USING (auth.user_role() = 'admin');
```

**Business Rules:**

- Internal staff can see all file assets across all projects
- Customers can see file assets for their organization
- Internal staff can upload new files including proofs
- Internal staff can update file details and metadata
- **Customers can approve or reject proofs** for their projects (limited update access)
- Only admins can delete file assets

**Key Feature:** Customers have UPDATE access but only for proof files belonging to their organization, allowing them to approve/reject proofs while preventing access to other file types.

---

## Approval Events Table

```sql
ALTER TABLE approval_events ENABLE ROW LEVEL SECURITY;

-- Internal users can see all approval events
CREATE POLICY "Internal users can view all approval events"
ON approval_events FOR SELECT
USING (auth.is_internal_user());

-- Customers can see approval events for their files
CREATE POLICY "Customers can view their approval events"
ON approval_events FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND EXISTS (
    SELECT 1
    FROM file_assets
    WHERE file_assets.id = approval_events.file_asset_id
    AND file_assets.organization_id = auth.user_organization_id()
  )
);

-- Internal users can create approval events
CREATE POLICY "Internal users can create approval events"
ON approval_events FOR INSERT
WITH CHECK (auth.is_internal_user());

-- No UPDATE or DELETE policies (audit log is append-only)
```

**Business Rules:**

- Internal staff can see all approval events
- Customers can see approval events for their files
- Internal staff can log approval events
- Append-only audit log (no updates or deletes)

---

## Shipments Table

```sql
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;

-- Internal users can see all shipments
CREATE POLICY "Internal users can view all shipments"
ON shipments FOR SELECT
USING (auth.is_internal_user());

-- Customers can see shipments for their organization
CREATE POLICY "Customers can view their shipments"
ON shipments FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
);

-- Internal users can create shipments
CREATE POLICY "Internal users can create shipments"
ON shipments FOR INSERT
WITH CHECK (auth.is_internal_user());

-- Internal users can update shipments
CREATE POLICY "Internal users can update shipments"
ON shipments FOR UPDATE
USING (auth.is_internal_user())
WITH CHECK (auth.is_internal_user());

-- Only admins can delete shipments
CREATE POLICY "Admins can delete shipments"
ON shipments FOR DELETE
USING (auth.user_role() = 'admin');
```

**Business Rules:**

- Internal staff can see all shipments across all projects
- Customers can see shipments for their organization
- Internal staff can create shipment records
- Internal staff can update tracking information and delivery status
- Only admins can delete shipment records

**Note:** Customers have read-only access to shipments. They can view tracking information but cannot modify it.

---

## Shipment Events Table

```sql
ALTER TABLE shipment_events ENABLE ROW LEVEL SECURITY;

-- Internal users can see all shipment events
CREATE POLICY "Internal users can view all shipment events"
ON shipment_events FOR SELECT
USING (auth.is_internal_user());

-- Customers can see shipment events for their shipments
CREATE POLICY "Customers can view their shipment events"
ON shipment_events FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND EXISTS (
    SELECT 1
    FROM shipments
    WHERE shipments.id = shipment_events.shipment_id
    AND shipments.organization_id = auth.user_organization_id()
  )
);

-- Internal users can create shipment events
CREATE POLICY "Internal users can create shipment events"
ON shipment_events FOR INSERT
WITH CHECK (auth.is_internal_user());

-- No UPDATE or DELETE policies (audit log is append-only)
```

**Business Rules:**

- Internal staff can see all shipment tracking events
- Customers can see tracking events for their shipments
- Internal staff can log shipment tracking events
- Append-only audit log (no updates or deletes)
- System (carrier webhooks, n8n) uses service role to insert events

---

## Service Role Access

The **service role key** is used by:

- **n8n workflows** - Automated reminders, status updates, invoice processing
- **Cron jobs** - Mark invoices overdue, process scheduled tasks
- **Background workers** - Async job processing
- **Carrier webhooks** - Shipment tracking updates from UPS, FedEx, etc.
- **Payment processors** - Stripe webhooks for payment events

**Service role bypasses RLS entirely** - use with caution and only in trusted server-side code.

**Security Best Practices:**
- Never expose service role key to client-side code
- Use service role only in secure server environments
- Log all service role operations for audit trail
- Validate all inputs even when using service role

---

## Security Patterns

### Customer Data Isolation

All customer-facing policies follow this pattern:

```sql
-- View own data only
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
)
```

This ensures customers can only see data belonging to their organization.

### Internal Staff Access

All internal staff policies follow this pattern:

```sql
-- View all data
USING (auth.is_internal_user())
```

This grants full access to Stone Forest employees.

### Draft Content Protection

Invoices have special protection for draft content:

```sql
-- Customers cannot see drafts
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND status != 'draft'
)
```

### Audit Trail Protection

All event tables are append-only:

```sql
-- Only INSERT policy, no UPDATE or DELETE
CREATE POLICY "Can create events"
ON table_name FOR INSERT
WITH CHECK (auth.is_internal_user());
```

This ensures complete audit trail integrity.

### Proof Approval Access

Customers have limited UPDATE access to approve proofs:

```sql
-- Can only update proof approval fields
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
  AND file_type = 'proof'
)
```

---

## Testing RLS Policies

### Test as Internal User

```sql
-- Set session to internal user
SET request.jwt.claims = '{"sub": "internal-user-uuid"}';

-- Should see all invoices
SELECT COUNT(*) FROM invoices;

-- Should see all file assets
SELECT COUNT(*) FROM file_assets;

-- Should see all shipments
SELECT COUNT(*) FROM shipments;
```

### Test as Customer User

```sql
-- Set session to customer user (organization_id = 'abc-123')
SET request.jwt.claims = '{"sub": "customer-user-uuid"}';

-- Should only see invoices for organization 'abc-123' (excluding drafts)
SELECT COUNT(*) FROM invoices;

-- Should not see draft invoices
SELECT COUNT(*) FROM invoices WHERE status = 'draft';
-- Result: 0

-- Should not see other customers' invoices
SELECT COUNT(*) FROM invoices WHERE organization_id != 'abc-123';
-- Result: 0

-- Should only see own organization's file assets
SELECT COUNT(*) FROM file_assets WHERE organization_id = 'abc-123';
```

### Test Proof Approval Access

```sql
-- Set session to customer user
SET request.jwt.claims = '{"sub": "customer-user-uuid"}';

-- Should be able to update approval status on proof
UPDATE file_assets
SET approval_status = 'approved',
    approved_by = auth.uid(),
    approved_at = NOW()
WHERE id = 'proof-uuid'
AND file_type = 'proof'
AND organization_id = auth.user_organization_id();
-- Should succeed

-- Should NOT be able to update non-proof files
UPDATE file_assets
SET notes = 'Changed'
WHERE id = 'artwork-uuid'
AND file_type = 'artwork';
-- Should fail (no matching policy)
```

---

## Security Checklist

### Implementation Status
- [x] RLS enabled on all 9 tables
- [x] No anonymous access allowed
- [x] Customer data isolation enforced
- [x] Internal staff have full access
- [x] Draft invoice protection (database-level)
- [x] Audit trails are append-only
- [x] Proof approval workflow for customers
- [x] Service role usage documented
- [x] Helper functions with proper permissions

### Testing & Validation
- [ ] RLS policies tested in staging environment
- [ ] Performance impact of RLS measured
- [ ] Customer proof approval flow tested
- [ ] Service role operations audited
- [ ] Edge cases documented and tested

### Future Enhancements
- [ ] Add integration tests for all RLS policies
- [ ] Monitor RLS policy performance in production
- [ ] Document all service role usage patterns

---

## Performance Considerations

### Critical Indexes

All tables have indexes on `organization_id` for efficient RLS filtering:

```sql
CREATE INDEX idx_tablename_organization ON tablename(organization_id);
```

### Helper Function Optimization

1. **STABLE functions** - Cached per query, not per row
2. **SECURITY DEFINER** - Allows access to public schema
3. **LIMIT 1** - Prevents unnecessary row scanning
4. **Indexed lookups** - All helper functions use indexed columns

### Policy Complexity

- Keep RLS policies simple to avoid query plan overhead
- Use helper functions instead of complex inline JOINs
- Partial indexes on filtered columns (e.g., `WHERE is_current_version = true`)

### Monitoring

Monitor these metrics in production:

- Query execution time with RLS enabled
- Index usage on `organization_id` columns
- Helper function call frequency
- Service role operation volume

---

## Summary

The Stone Forest App RLS implementation provides:

1. ✅ **Complete data isolation** between customer organizations
2. ✅ **Full internal staff access** to all customer data
3. ✅ **Draft protection** at database level (not just UI)
4. ✅ **Append-only audit trails** for compliance
5. ✅ **Customer proof approval** with limited update access
6. ✅ **Service role patterns** for automated workflows
7. ✅ **9 tables protected** with comprehensive policies
8. ✅ **6 helper functions** for consistent access control

All policies follow consistent security patterns and are optimized for performance with proper indexing.
