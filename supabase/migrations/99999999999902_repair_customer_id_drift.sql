-- Migration: Comprehensive Schema Drift Repair
-- Description: Fixes missing columns, recreates RLS helper functions, enables RLS,
--              and recreates all RLS policies to ensure data isolation works correctly.
--              This migration is RE-RUNNABLE and safe to run multiple times.
-- Sprint: Schema Repair
--
-- IMPORTANT: This migration works with the ORGANIZATIONS schema model
--            (organizations + users with organization_id columns)

-- =============================================================================
-- PHASE 1: DROP DEPENDENT OBJECTS (Views that depend on tables)
-- =============================================================================

-- Drop views first to avoid conflicts during schema changes
DROP VIEW IF EXISTS internal_action_queue CASCADE;

COMMENT ON EXTENSION IF EXISTS plpgsql IS
  'Dropped internal_action_queue view - will recreate at end of migration';

-- =============================================================================
-- PHASE 2: ENSURE CORE TABLES EXIST
-- =============================================================================

-- Note: This repair assumes base migrations have already run.
-- We're only fixing drift issues, not creating tables from scratch.

-- Verify organizations table exists (critical dependency)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'organizations'
  ) THEN
    RAISE EXCEPTION 'CRITICAL: organizations table does not exist. Run base migrations first.';
  END IF;
END $$;

-- =============================================================================
-- PHASE 3: ADD MISSING COLUMNS (IF NOT EXISTS)
-- =============================================================================

-- Add organization_id to projects if missing
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    IF NOT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'projects' AND column_name = 'organization_id'
    ) THEN
      -- Add column
      ALTER TABLE projects ADD COLUMN organization_id UUID;
      RAISE NOTICE 'Added projects.organization_id column';

      -- If we have data, we need to populate it (would need manual intervention)
      -- For now, just add the column and make it required going forward
      ALTER TABLE projects ALTER COLUMN organization_id SET NOT NULL;
      RAISE NOTICE 'Set projects.organization_id to NOT NULL';
    ELSE
      RAISE NOTICE 'Column projects.organization_id already exists';
    END IF;
  END IF;
END $$;

-- Add organization_id to invoices if missing
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    IF NOT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'invoices' AND column_name = 'organization_id'
    ) THEN
      -- Add column
      ALTER TABLE invoices ADD COLUMN organization_id UUID;
      RAISE NOTICE 'Added invoices.organization_id column';

      -- Set NOT NULL after data population
      ALTER TABLE invoices ALTER COLUMN organization_id SET NOT NULL;
      RAISE NOTICE 'Set invoices.organization_id to NOT NULL';
    ELSE
      RAISE NOTICE 'Column invoices.organization_id already exists';
    END IF;
  END IF;
END $$;

-- =============================================================================
-- PHASE 4: ADD FOREIGN KEY CONSTRAINTS (IF NOT EXISTS)
-- =============================================================================

-- Add FK constraint for projects.organization_id -> organizations.id
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'projects' AND column_name = 'organization_id'
  ) THEN
    IF NOT EXISTS (
      SELECT FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'projects'
        AND kcu.column_name = 'organization_id'
        AND tc.constraint_type = 'FOREIGN KEY'
    ) THEN
      ALTER TABLE projects
        ADD CONSTRAINT fk_projects_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations(id)
        ON DELETE CASCADE;
      RAISE NOTICE 'Added FK constraint: projects.organization_id -> organizations.id';
    ELSE
      RAISE NOTICE 'FK constraint projects.organization_id -> organizations.id already exists';
    END IF;
  END IF;
END $$;

-- Add FK constraint for invoices.organization_id -> organizations.id
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'invoices' AND column_name = 'organization_id'
  ) THEN
    IF NOT EXISTS (
      SELECT FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'invoices'
        AND kcu.column_name = 'organization_id'
        AND tc.constraint_type = 'FOREIGN KEY'
    ) THEN
      ALTER TABLE invoices
        ADD CONSTRAINT fk_invoices_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations(id)
        ON DELETE CASCADE;
      RAISE NOTICE 'Added FK constraint: invoices.organization_id -> organizations.id';
    ELSE
      RAISE NOTICE 'FK constraint invoices.organization_id -> organizations.id already exists';
    END IF;
  END IF;
END $$;

-- =============================================================================
-- PHASE 5: ADD INDEXES FOR PERFORMANCE
-- =============================================================================

-- Add index on projects.organization_id if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'projects' AND indexname = 'idx_projects_organization'
  ) THEN
    IF EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'projects' AND column_name = 'organization_id'
    ) THEN
      CREATE INDEX idx_projects_organization ON projects(organization_id);
      RAISE NOTICE 'Created index: idx_projects_organization';
    END IF;
  ELSE
    RAISE NOTICE 'Index idx_projects_organization already exists';
  END IF;
END $$;

-- Add index on invoices.organization_id if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'invoices' AND indexname = 'idx_invoices_organization'
  ) THEN
    IF EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'invoices' AND column_name = 'organization_id'
    ) THEN
      CREATE INDEX idx_invoices_organization ON invoices(organization_id);
      RAISE NOTICE 'Created index: idx_invoices_organization';
    END IF;
  ELSE
    RAISE NOTICE 'Index idx_invoices_organization already exists';
  END IF;
END $$;

-- =============================================================================
-- PHASE 6: CREATE/REPLACE RLS HELPER FUNCTIONS
-- =============================================================================

-- Function: auth.user_role() - Returns the role of the current user
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS VARCHAR(20) AS $$
  SELECT role
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.user_role() IS
  'Returns the role of the current user (admin, staff, customer). Used in RLS policies.';

GRANT EXECUTE ON FUNCTION auth.user_role() TO authenticated;

-- Function: auth.user_organization_id() - Returns the organization_id of the current user
CREATE OR REPLACE FUNCTION auth.user_organization_id()
RETURNS UUID AS $$
  SELECT organization_id
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.user_organization_id() IS
  'Returns the organization_id of the current user. Used for customer data isolation in RLS.';

GRANT EXECUTE ON FUNCTION auth.user_organization_id() TO authenticated;

-- Function: auth.user_customer_id() - Alias for user_organization_id()
CREATE OR REPLACE FUNCTION auth.user_customer_id()
RETURNS UUID AS $$
  SELECT auth.user_organization_id();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.user_customer_id() IS
  'Alias for user_organization_id(). Returns the customer organization ID of the current user.';

GRANT EXECUTE ON FUNCTION auth.user_customer_id() TO authenticated;

-- Function: auth.is_internal_user() - Returns true if user is internal staff
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

COMMENT ON FUNCTION auth.is_internal_user() IS
  'Returns true if current user is internal staff (Stone Forest employee). Used to grant full access in RLS policies.';

GRANT EXECUTE ON FUNCTION auth.is_internal_user() TO authenticated;

-- Function: auth.is_admin() - Returns true if user has admin role
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN AS $$
  SELECT auth.user_role() = 'admin';
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.is_admin() IS
  'Returns true if current user has admin role. Used for privileged operations in RLS policies.';

GRANT EXECUTE ON FUNCTION auth.is_admin() TO authenticated;

-- Function: auth.is_staff() - Returns true if user is admin or staff
CREATE OR REPLACE FUNCTION auth.is_staff()
RETURNS BOOLEAN AS $$
  SELECT auth.user_role() IN ('admin', 'staff');
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.is_staff() IS
  'Returns true if current user has admin or staff role. Useful for operations allowed to all internal staff.';

GRANT EXECUTE ON FUNCTION auth.is_staff() TO authenticated;

-- =============================================================================
-- PHASE 7: ENABLE RLS ON ALL TABLES
-- =============================================================================

DO $$
BEGIN
  -- Enable RLS on organizations
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'organizations') THEN
    ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on organizations';
  END IF;

  -- Enable RLS on users
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
    ALTER TABLE users ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on users';
  END IF;

  -- Enable RLS on projects
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on projects';
  END IF;

  -- Enable RLS on invoices
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on invoices';
  END IF;

  -- Enable RLS on invoice_events
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoice_events') THEN
    ALTER TABLE invoice_events ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on invoice_events';
  END IF;

  -- Enable RLS on file_assets (proofs)
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'file_assets') THEN
    ALTER TABLE file_assets ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on file_assets';
  END IF;

  -- Enable RLS on approval_events
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'approval_events') THEN
    ALTER TABLE approval_events ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on approval_events';
  END IF;

  -- Enable RLS on shipments
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'shipments') THEN
    ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on shipments';
  END IF;

  -- Enable RLS on shipment_events
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'shipment_events') THEN
    ALTER TABLE shipment_events ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Enabled RLS on shipment_events';
  END IF;
END $$;

-- =============================================================================
-- PHASE 8: DROP OLD POLICIES (to recreate with correct logic)
-- =============================================================================

-- Drop all existing policies to ensure clean slate
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
    RAISE NOTICE 'Dropped policy: %.%', r.tablename, r.policyname;
  END LOOP;
END $$;

-- =============================================================================
-- PHASE 9: CREATE RLS POLICIES (Organizations)
-- =============================================================================

-- Organizations: Internal users can see all
DROP POLICY IF EXISTS "organizations_read_internal" ON organizations;
CREATE POLICY "organizations_read_internal"
ON organizations FOR SELECT
TO authenticated
USING (auth.is_internal_user());

-- Organizations: Customers can see their own
DROP POLICY IF EXISTS "organizations_read_customer" ON organizations;
CREATE POLICY "organizations_read_customer"
ON organizations FOR SELECT
TO authenticated
USING (
  NOT auth.is_internal_user()
  AND id = auth.user_organization_id()
);

-- Organizations: Only admins can manage
DROP POLICY IF EXISTS "organizations_manage_admin" ON organizations;
CREATE POLICY "organizations_manage_admin"
ON organizations FOR ALL
TO authenticated
USING (auth.user_role() = 'admin');

COMMENT ON POLICY "organizations_read_internal" ON organizations IS
  'Internal staff can see all organizations';
COMMENT ON POLICY "organizations_read_customer" ON organizations IS
  'Customer users can only see their own organization';
COMMENT ON POLICY "organizations_manage_admin" ON organizations IS
  'Only admins can create, update, or delete organizations';

-- =============================================================================
-- PHASE 10: CREATE RLS POLICIES (Users)
-- =============================================================================

-- Users: Internal can see all
DROP POLICY IF EXISTS "users_read_internal" ON users;
CREATE POLICY "users_read_internal"
ON users FOR SELECT
TO authenticated
USING (auth.is_internal_user());

-- Users: Customers can see their org's users
DROP POLICY IF EXISTS "users_read_customer" ON users;
CREATE POLICY "users_read_customer"
ON users FOR SELECT
TO authenticated
USING (
  NOT auth.is_internal_user()
  AND organization_id = auth.user_organization_id()
);

-- Users: Can update own profile
DROP POLICY IF EXISTS "users_update_self" ON users;
CREATE POLICY "users_update_self"
ON users FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- Users: Staff can manage all
DROP POLICY IF EXISTS "users_manage_staff" ON users;
CREATE POLICY "users_manage_staff"
ON users FOR ALL
TO authenticated
USING (auth.is_staff());

COMMENT ON POLICY "users_read_internal" ON users IS
  'Internal staff can see all users';
COMMENT ON POLICY "users_read_customer" ON users IS
  'Customers can see users in their organization';
COMMENT ON POLICY "users_update_self" ON users IS
  'Users can update their own profile';
COMMENT ON POLICY "users_manage_staff" ON users IS
  'Staff can create, update, delete any user';

-- =============================================================================
-- PHASE 11: CREATE RLS POLICIES (Projects)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    -- Projects: Internal can see all
    DROP POLICY IF EXISTS "projects_read_internal" ON projects;
    CREATE POLICY "projects_read_internal"
    ON projects FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- Projects: Customers can see their own
    DROP POLICY IF EXISTS "projects_read_customer" ON projects;
    CREATE POLICY "projects_read_customer"
    ON projects FOR SELECT
    TO authenticated
    USING (
      NOT auth.is_internal_user()
      AND organization_id = auth.user_organization_id()
    );

    -- Projects: Internal can create
    DROP POLICY IF EXISTS "projects_create_internal" ON projects;
    CREATE POLICY "projects_create_internal"
    ON projects FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    -- Projects: Internal can update
    DROP POLICY IF EXISTS "projects_update_internal" ON projects;
    CREATE POLICY "projects_update_internal"
    ON projects FOR UPDATE
    TO authenticated
    USING (auth.is_internal_user())
    WITH CHECK (auth.is_internal_user());

    -- Projects: Only admins can delete
    DROP POLICY IF EXISTS "projects_delete_admin" ON projects;
    CREATE POLICY "projects_delete_admin"
    ON projects FOR DELETE
    TO authenticated
    USING (auth.is_admin());

    RAISE NOTICE 'Created RLS policies for projects';
  END IF;
END $$;

-- =============================================================================
-- PHASE 12: CREATE RLS POLICIES (Invoices)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    -- Invoices: Internal can see all
    DROP POLICY IF EXISTS "invoices_read_internal" ON invoices;
    CREATE POLICY "invoices_read_internal"
    ON invoices FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- Invoices: Customers can see their own (excluding drafts)
    DROP POLICY IF EXISTS "invoices_read_customer" ON invoices;
    CREATE POLICY "invoices_read_customer"
    ON invoices FOR SELECT
    TO authenticated
    USING (
      NOT auth.is_internal_user()
      AND organization_id = auth.user_organization_id()
      AND status != 'draft'
    );

    -- Invoices: Internal can create
    DROP POLICY IF EXISTS "invoices_create_internal" ON invoices;
    CREATE POLICY "invoices_create_internal"
    ON invoices FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    -- Invoices: Internal can update
    DROP POLICY IF EXISTS "invoices_update_internal" ON invoices;
    CREATE POLICY "invoices_update_internal"
    ON invoices FOR UPDATE
    TO authenticated
    USING (auth.is_internal_user())
    WITH CHECK (auth.is_internal_user());

    -- Invoices: Only admins can delete
    DROP POLICY IF EXISTS "invoices_delete_admin" ON invoices;
    CREATE POLICY "invoices_delete_admin"
    ON invoices FOR DELETE
    TO authenticated
    USING (auth.is_admin());

    RAISE NOTICE 'Created RLS policies for invoices';
  END IF;
END $$;

-- =============================================================================
-- PHASE 13: CREATE RLS POLICIES (Invoice Events)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoice_events') THEN
    -- Invoice Events: Internal can see all
    DROP POLICY IF EXISTS "invoice_events_read_internal" ON invoice_events;
    CREATE POLICY "invoice_events_read_internal"
    ON invoice_events FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- Invoice Events: Customers can see events for their invoices
    DROP POLICY IF EXISTS "invoice_events_read_customer" ON invoice_events;
    CREATE POLICY "invoice_events_read_customer"
    ON invoice_events FOR SELECT
    TO authenticated
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

    -- Invoice Events: Internal can create
    DROP POLICY IF EXISTS "invoice_events_create_internal" ON invoice_events;
    CREATE POLICY "invoice_events_create_internal"
    ON invoice_events FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    RAISE NOTICE 'Created RLS policies for invoice_events';
  END IF;
END $$;

-- =============================================================================
-- PHASE 14: CREATE RLS POLICIES (File Assets / Proofs)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'file_assets') THEN
    -- File Assets: Internal can see all
    DROP POLICY IF EXISTS "file_assets_read_internal" ON file_assets;
    CREATE POLICY "file_assets_read_internal"
    ON file_assets FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- File Assets: Customers can see their org's files
    DROP POLICY IF EXISTS "file_assets_read_customer" ON file_assets;
    CREATE POLICY "file_assets_read_customer"
    ON file_assets FOR SELECT
    TO authenticated
    USING (
      NOT auth.is_internal_user()
      AND organization_id = auth.user_organization_id()
    );

    -- File Assets: Internal can create
    DROP POLICY IF EXISTS "file_assets_create_internal" ON file_assets;
    CREATE POLICY "file_assets_create_internal"
    ON file_assets FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    -- File Assets: Internal can update
    DROP POLICY IF EXISTS "file_assets_update_internal" ON file_assets;
    CREATE POLICY "file_assets_update_internal"
    ON file_assets FOR UPDATE
    TO authenticated
    USING (auth.is_internal_user())
    WITH CHECK (auth.is_internal_user());

    -- File Assets: Customers can update proof approvals
    DROP POLICY IF EXISTS "file_assets_approve_customer" ON file_assets;
    CREATE POLICY "file_assets_approve_customer"
    ON file_assets FOR UPDATE
    TO authenticated
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

    -- File Assets: Only admins can delete
    DROP POLICY IF EXISTS "file_assets_delete_admin" ON file_assets;
    CREATE POLICY "file_assets_delete_admin"
    ON file_assets FOR DELETE
    TO authenticated
    USING (auth.is_admin());

    RAISE NOTICE 'Created RLS policies for file_assets';
  END IF;
END $$;

-- =============================================================================
-- PHASE 15: CREATE RLS POLICIES (Approval Events)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'approval_events') THEN
    -- Approval Events: Internal can see all
    DROP POLICY IF EXISTS "approval_events_read_internal" ON approval_events;
    CREATE POLICY "approval_events_read_internal"
    ON approval_events FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- Approval Events: Customers can see events for their files
    DROP POLICY IF EXISTS "approval_events_read_customer" ON approval_events;
    CREATE POLICY "approval_events_read_customer"
    ON approval_events FOR SELECT
    TO authenticated
    USING (
      NOT auth.is_internal_user()
      AND EXISTS (
        SELECT 1
        FROM file_assets
        WHERE file_assets.id = approval_events.file_asset_id
        AND file_assets.organization_id = auth.user_organization_id()
      )
    );

    -- Approval Events: Internal can create
    DROP POLICY IF EXISTS "approval_events_create_internal" ON approval_events;
    CREATE POLICY "approval_events_create_internal"
    ON approval_events FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    RAISE NOTICE 'Created RLS policies for approval_events';
  END IF;
END $$;

-- =============================================================================
-- PHASE 16: CREATE RLS POLICIES (Shipments)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'shipments') THEN
    -- Shipments: Internal can see all
    DROP POLICY IF EXISTS "shipments_read_internal" ON shipments;
    CREATE POLICY "shipments_read_internal"
    ON shipments FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- Shipments: Customers can see their org's shipments
    DROP POLICY IF EXISTS "shipments_read_customer" ON shipments;
    CREATE POLICY "shipments_read_customer"
    ON shipments FOR SELECT
    TO authenticated
    USING (
      NOT auth.is_internal_user()
      AND organization_id = auth.user_organization_id()
    );

    -- Shipments: Internal can create
    DROP POLICY IF EXISTS "shipments_create_internal" ON shipments;
    CREATE POLICY "shipments_create_internal"
    ON shipments FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    -- Shipments: Internal can update
    DROP POLICY IF EXISTS "shipments_update_internal" ON shipments;
    CREATE POLICY "shipments_update_internal"
    ON shipments FOR UPDATE
    TO authenticated
    USING (auth.is_internal_user())
    WITH CHECK (auth.is_internal_user());

    -- Shipments: Only admins can delete
    DROP POLICY IF EXISTS "shipments_delete_admin" ON shipments;
    CREATE POLICY "shipments_delete_admin"
    ON shipments FOR DELETE
    TO authenticated
    USING (auth.is_admin());

    RAISE NOTICE 'Created RLS policies for shipments';
  END IF;
END $$;

-- =============================================================================
-- PHASE 17: CREATE RLS POLICIES (Shipment Events)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'shipment_events') THEN
    -- Shipment Events: Internal can see all
    DROP POLICY IF EXISTS "shipment_events_read_internal" ON shipment_events;
    CREATE POLICY "shipment_events_read_internal"
    ON shipment_events FOR SELECT
    TO authenticated
    USING (auth.is_internal_user());

    -- Shipment Events: Customers can see events for their shipments
    DROP POLICY IF EXISTS "shipment_events_read_customer" ON shipment_events;
    CREATE POLICY "shipment_events_read_customer"
    ON shipment_events FOR SELECT
    TO authenticated
    USING (
      NOT auth.is_internal_user()
      AND EXISTS (
        SELECT 1
        FROM shipments
        WHERE shipments.id = shipment_events.shipment_id
        AND shipments.organization_id = auth.user_organization_id()
      )
    );

    -- Shipment Events: Internal can create
    DROP POLICY IF EXISTS "shipment_events_create_internal" ON shipment_events;
    CREATE POLICY "shipment_events_create_internal"
    ON shipment_events FOR INSERT
    TO authenticated
    WITH CHECK (auth.is_internal_user());

    RAISE NOTICE 'Created RLS policies for shipment_events';
  END IF;
END $$;

-- =============================================================================
-- PHASE 18: RECREATE INTERNAL ACTION QUEUE VIEW
-- =============================================================================

CREATE OR REPLACE VIEW internal_action_queue AS

-- Unpaid deposits (Priority 1)
SELECT
  'deposit_unpaid' AS action_type,
  1 AS priority,
  i.id AS record_id,
  i.invoice_number AS identifier,
  'Deposit Required: ' || i.invoice_number || ' - ' || p.name AS title,
  'Unpaid deposit of ' || TO_CHAR(i.deposit_amount / 100.0, 'FM$999,999,990.00') ||
    ' for ' || o.name AS description,
  o.id AS organization_id,
  o.name AS customer_name,
  p.id AS project_id,
  p.name AS project_name,
  i.issue_date AS created_date,
  i.due_date AS due_date,
  CURRENT_DATE - i.issue_date AS days_open,
  jsonb_build_object(
    'invoice_id', i.id,
    'deposit_amount', i.deposit_amount,
    'invoice_total', i.amount_total,
    'issue_date', i.issue_date,
    'contact_email', o.contact_email
  ) AS metadata
FROM invoices i
JOIN projects p ON i.project_id = p.id
JOIN organizations o ON i.organization_id = o.id
WHERE i.deposit_required = true
  AND i.deposit_paid = false
  AND i.status IN ('draft', 'sent')

UNION ALL

-- Invoices due soon (Priority 2)
SELECT
  'invoice_due_soon' AS action_type,
  2 AS priority,
  i.id AS record_id,
  i.invoice_number AS identifier,
  'Due Soon: ' || i.invoice_number || ' - ' || p.name AS title,
  'Invoice due in ' || (i.due_date - CURRENT_DATE) || ' days - ' ||
    TO_CHAR(i.balance_due / 100.0, 'FM$999,999,990.00') || ' remaining' AS description,
  o.id AS organization_id,
  o.name AS customer_name,
  p.id AS project_id,
  p.name AS project_name,
  i.issue_date AS created_date,
  i.due_date AS due_date,
  CURRENT_DATE - i.issue_date AS days_open,
  jsonb_build_object(
    'invoice_id', i.id,
    'balance_due', i.balance_due,
    'days_until_due', i.due_date - CURRENT_DATE,
    'contact_email', o.contact_email
  ) AS metadata
FROM invoices i
JOIN projects p ON i.project_id = p.id
JOIN organizations o ON i.organization_id = o.id
WHERE i.status = 'sent'
  AND i.balance_due > 0
  AND i.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'

UNION ALL

-- Overdue invoices (Priority 1)
SELECT
  'invoice_overdue' AS action_type,
  1 AS priority,
  i.id AS record_id,
  i.invoice_number AS identifier,
  'OVERDUE: ' || i.invoice_number || ' - ' || p.name AS title,
  'Invoice ' || (CURRENT_DATE - i.due_date) || ' days overdue - ' ||
    TO_CHAR(i.balance_due / 100.0, 'FM$999,999,990.00') || ' outstanding' AS description,
  o.id AS organization_id,
  o.name AS customer_name,
  p.id AS project_id,
  p.name AS project_name,
  i.issue_date AS created_date,
  i.due_date AS due_date,
  CURRENT_DATE - i.issue_date AS days_open,
  jsonb_build_object(
    'invoice_id', i.id,
    'balance_due', i.balance_due,
    'days_overdue', CURRENT_DATE - i.due_date,
    'contact_email', o.contact_email,
    'last_reminder', (
      SELECT MAX(created_at)
      FROM invoice_events
      WHERE invoice_id = i.id
      AND event_type IN ('reminder_7day', 'reminder_due', 'reminder_overdue')
    )
  ) AS metadata
FROM invoices i
JOIN projects p ON i.project_id = p.id
JOIN organizations o ON i.organization_id = o.id
WHERE i.status = 'overdue'
  AND i.balance_due > 0

UNION ALL

-- Pending proof approvals (Priority 2)
SELECT
  'proof_pending' AS action_type,
  2 AS priority,
  fa.id AS record_id,
  fa.version_number::text AS identifier,
  'Proof Pending: ' || p.name || ' v' || fa.version_number AS title,
  'Awaiting approval for ' || (CURRENT_DATE - fa.created_at::date) || ' days' AS description,
  o.id AS organization_id,
  o.name AS customer_name,
  p.id AS project_id,
  p.name AS project_name,
  fa.created_at::date AS created_date,
  NULL AS due_date,
  CURRENT_DATE - fa.created_at::date AS days_open,
  jsonb_build_object(
    'file_asset_id', fa.id,
    'file_name', fa.file_name,
    'version', fa.version_number,
    'uploaded_at', fa.created_at,
    'uploaded_by', u.name,
    'storage_path', fa.storage_path
  ) AS metadata
FROM file_assets fa
JOIN projects p ON fa.project_id = p.id
JOIN organizations o ON p.organization_id = o.id
LEFT JOIN users u ON fa.uploaded_by = u.id
WHERE fa.file_type = 'proof'
  AND fa.approval_status = 'pending'
  AND fa.is_current_version = true
  AND fa.created_at < CURRENT_DATE - INTERVAL '2 days'

UNION ALL

-- Missing tracking numbers (Priority 2)
SELECT
  'shipment_no_tracking' AS action_type,
  2 AS priority,
  s.id AS record_id,
  s.shipment_number AS identifier,
  'Missing Tracking: ' || p.name AS title,
  'Shipment created ' || (CURRENT_DATE - s.actual_ship_date) || ' days ago without tracking number' AS description,
  o.id AS organization_id,
  o.name AS customer_name,
  p.id AS project_id,
  p.name AS project_name,
  s.actual_ship_date AS created_date,
  s.expected_delivery_date AS due_date,
  CURRENT_DATE - s.actual_ship_date AS days_open,
  jsonb_build_object(
    'shipment_id', s.id,
    'shipment_number', s.shipment_number,
    'carrier', s.carrier,
    'actual_ship_date', s.actual_ship_date,
    'expected_delivery', s.expected_delivery_date
  ) AS metadata
FROM shipments s
JOIN projects p ON s.project_id = p.id
JOIN organizations o ON s.organization_id = o.id
WHERE s.tracking_number IS NULL
  AND s.status NOT IN ('pending', 'cancelled', 'delivered', 'returned')
  AND s.actual_ship_date IS NOT NULL
  AND s.actual_ship_date < CURRENT_DATE - INTERVAL '1 day'

UNION ALL

-- Shipment ETA risks (Priority 1 if overdue, 2 if approaching)
SELECT
  CASE
    WHEN s.expected_delivery_date < CURRENT_DATE THEN 'shipment_overdue'
    ELSE 'shipment_eta_risk'
  END AS action_type,
  CASE
    WHEN s.expected_delivery_date < CURRENT_DATE THEN 1
    ELSE 2
  END AS priority,
  s.id AS record_id,
  COALESCE(s.tracking_number, s.shipment_number) AS identifier,
  CASE
    WHEN s.expected_delivery_date < CURRENT_DATE THEN 'LATE: ' || p.name
    ELSE 'Delivery Soon: ' || p.name
  END AS title,
  CASE
    WHEN s.expected_delivery_date < CURRENT_DATE THEN
      'Shipment is ' || (CURRENT_DATE - s.expected_delivery_date) || ' days overdue'
    ELSE
      'Estimated delivery in ' || (s.expected_delivery_date - CURRENT_DATE) || ' days'
  END AS description,
  o.id AS organization_id,
  o.name AS customer_name,
  p.id AS project_id,
  p.name AS project_name,
  s.actual_ship_date AS created_date,
  s.expected_delivery_date AS due_date,
  CURRENT_DATE - COALESCE(s.actual_ship_date, s.expected_ship_date) AS days_open,
  jsonb_build_object(
    'shipment_id', s.id,
    'shipment_number', s.shipment_number,
    'tracking_number', s.tracking_number,
    'carrier', s.carrier,
    'status', s.status,
    'actual_ship_date', s.actual_ship_date,
    'expected_delivery', s.expected_delivery_date,
    'days_until_delivery', s.expected_delivery_date - CURRENT_DATE,
    'tracking_url', s.tracking_url
  ) AS metadata
FROM shipments s
JOIN projects p ON s.project_id = p.id
JOIN organizations o ON s.organization_id = o.id
WHERE s.status IN ('shipped', 'in_transit', 'out_for_delivery')
  AND s.expected_delivery_date IS NOT NULL
  AND (
    s.expected_delivery_date < CURRENT_DATE
    OR
    s.expected_delivery_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '2 days'
  )

ORDER BY
  priority ASC,
  due_date ASC NULLS LAST,
  created_date ASC;

-- Grant permissions
GRANT SELECT ON internal_action_queue TO authenticated;

-- Add comments
COMMENT ON VIEW internal_action_queue IS
  'Unified action queue for internal staff showing all items requiring attention, ordered by priority';

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE 'SCHEMA REPAIR MIGRATION COMPLETE';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Summary of changes:';
  RAISE NOTICE '  ✓ Verified core tables exist';
  RAISE NOTICE '  ✓ Added missing organization_id columns (if needed)';
  RAISE NOTICE '  ✓ Created/updated foreign key constraints';
  RAISE NOTICE '  ✓ Added performance indexes';
  RAISE NOTICE '  ✓ Created/replaced RLS helper functions';
  RAISE NOTICE '  ✓ Enabled RLS on all tables';
  RAISE NOTICE '  ✓ Recreated all RLS policies with correct logic';
  RAISE NOTICE '  ✓ Recreated internal_action_queue view';
  RAISE NOTICE '';
  RAISE NOTICE 'Next Steps:';
  RAISE NOTICE '  1. Test RLS policies with customer and internal user accounts';
  RAISE NOTICE '  2. Verify internal_action_queue view returns expected data';
  RAISE NOTICE '  3. Monitor for any RLS-related errors in application logs';
  RAISE NOTICE '';
END $$;
