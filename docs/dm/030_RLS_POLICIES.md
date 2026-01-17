# Row Level Security (RLS) Policies

## Overview

All tables in the Stone Forest App use Supabase Row Level Security (RLS) to enforce data isolation between customers and control access for internal staff.

**Security Principles:**

1. **Customers see only their own data** - Never data from other customers
2. **Internal staff see all data** - Full access for Stone Forest employees
3. **Authentication required** - No anonymous access
4. **Audit trail** - All data modifications logged

---

## Helper Functions

### Get Current User's Organization

```sql
CREATE OR REPLACE FUNCTION auth.user_organization_id()
RETURNS UUID AS $$
  SELECT organization_id
  FROM users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE;
```

### Check if User is Internal Staff

```sql
CREATE OR REPLACE FUNCTION auth.is_internal_user()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM users u
    JOIN organizations o ON u.organization_id = o.id
    WHERE u.auth_user_id = auth.uid()
    AND o.type = 'internal'
  );
$$ LANGUAGE SQL STABLE;
```

### Get User Role

```sql
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS VARCHAR(20) AS $$
  SELECT role
  FROM users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE;
```

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
USING (auth_user_id = auth.uid());

-- Admins can manage all users
CREATE POLICY "Admins can manage users"
ON users FOR ALL
USING (auth.user_role() = 'admin');
```

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

-- Internal staff can create/update projects
CREATE POLICY "Internal users can manage projects"
ON projects FOR ALL
USING (auth.is_internal_user());
```

---

## Invoices Table (Sprint 001)

```sql
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Internal users can see all invoices
CREATE POLICY "Internal users can view all invoices"
ON invoices FOR SELECT
USING (auth.is_internal_user());

-- Customers can see their organization's invoices
CREATE POLICY "Customers can view their invoices"
ON invoices FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
);

-- Only internal staff can create invoices
CREATE POLICY "Internal users can create invoices"
ON invoices FOR INSERT
WITH CHECK (auth.is_internal_user());

-- Only internal staff can update invoices
CREATE POLICY "Internal users can update invoices"
ON invoices FOR UPDATE
USING (auth.is_internal_user());

-- Only admins can delete invoices
CREATE POLICY "Admins can delete invoices"
ON invoices FOR DELETE
USING (auth.user_role() = 'admin');
```

**Business Rules:**

- Customers can **view** invoices but cannot modify them
- Internal staff can **create and update** invoices
- Only admins can **delete** invoices (rare, for corrections)
- Draft invoices may be hidden from customers (enforced in application layer)

---

## Invoice Events Table (Sprint 001)

```sql
ALTER TABLE invoice_events ENABLE ROW LEVEL SECURITY;

-- Internal users can see all invoice events
CREATE POLICY "Internal users can view all invoice events"
ON invoice_events FOR SELECT
USING (auth.is_internal_user());

-- Customers can see events for their invoices
CREATE POLICY "Customers can view their invoice events"
ON invoice_events FOR SELECT
USING (
  NOT auth.is_internal_user()
  AND EXISTS (
    SELECT 1
    FROM invoices
    WHERE invoices.id = invoice_events.invoice_id
    AND invoices.organization_id = auth.user_organization_id()
  )
);

-- System can insert events (for n8n, cron jobs)
-- Note: Service role key bypasses RLS entirely

-- Internal users can manually create events
CREATE POLICY "Internal users can create invoice events"
ON invoice_events FOR INSERT
WITH CHECK (auth.is_internal_user());

-- No updates or deletes (audit log is append-only)
-- Admins can delete if absolutely necessary via service role
```

**Event Visibility for Customers:**

Customers can see **most** events, but certain events may be filtered in the application layer:

- ✅ Visible: `sent`, `payment_received`, `reminder_*`
- ❌ Hidden: `created`, internal notes

---

## Service Role Access

The **service role key** is used by:

- n8n workflows (automated reminders, status updates)
- Cron jobs (mark invoices overdue)
- Background workers

**Service role bypasses RLS entirely** - use with caution and only in trusted server-side code.

---

## Testing RLS Policies

### Test as Internal User

```sql
-- Set session to internal user
SET request.jwt.claims = '{"sub": "internal-user-uuid"}';

-- Should see all invoices
SELECT COUNT(*) FROM invoices;
```

### Test as Customer User

```sql
-- Set session to customer user (organization_id = 'abc-123')
SET request.jwt.claims = '{"sub": "customer-user-uuid"}';

-- Should only see invoices for organization 'abc-123'
SELECT COUNT(*) FROM invoices;

-- Should not see other customers' invoices
SELECT COUNT(*) FROM invoices WHERE organization_id != 'abc-123';
-- Result: 0
```

---

## Security Checklist

- [x] RLS enabled on all tables
- [x] No anonymous access allowed
- [x] Customer data isolation enforced
- [x] Internal staff have full access
- [x] Audit trail (invoice_events) is append-only
- [x] Service role usage documented
- [ ] RLS policies tested in staging environment
- [ ] Performance impact of RLS measured (add indexes if needed)

---

## Performance Considerations

1. **Indexes on organization_id**: Critical for RLS query performance
2. **Helper function caching**: `STABLE` functions are cached per query
3. **Avoid complex JOINs in policies**: Keep RLS policies simple for performance

---

## Future Enhancements

- **Time-based access**: Hide overdue invoices older than 90 days from customer view
- **User permissions table**: More granular role-based access control
- **IP whitelisting**: Restrict admin actions to office IP ranges
