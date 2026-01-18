-- Migration: Create RLS Helper Functions
-- Description: Sets up helper functions for Row Level Security policies.
--              These functions are used across all RLS policies to determine user context.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- RLS HELPER FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Get Current User's Role
-- -----------------------------------------------------------------------------

-- Returns the role of the currently authenticated user (admin, staff, customer)
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS VARCHAR(20) AS $$
  SELECT role
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.user_role() IS
  'Returns the role of the current user (admin, staff, customer). Used in RLS policies.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.user_role() TO authenticated;

-- -----------------------------------------------------------------------------
-- Get Current User's Organization ID
-- -----------------------------------------------------------------------------

-- Returns the organization_id of the currently authenticated user
CREATE OR REPLACE FUNCTION auth.user_organization_id()
RETURNS UUID AS $$
  SELECT organization_id
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.user_organization_id() IS
  'Returns the organization_id of the current user. Used for customer data isolation in RLS.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.user_organization_id() TO authenticated;

-- -----------------------------------------------------------------------------
-- Get Current User's Customer ID (Alias)
-- -----------------------------------------------------------------------------

-- Alias for user_organization_id() - returns customer organization ID
-- This provides semantic clarity when used in customer-facing contexts
CREATE OR REPLACE FUNCTION auth.user_customer_id()
RETURNS UUID AS $$
  SELECT auth.user_organization_id();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.user_customer_id() IS
  'Alias for user_organization_id(). Returns the customer organization ID of the current user.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.user_customer_id() TO authenticated;

-- -----------------------------------------------------------------------------
-- Check if Current User is Internal Staff
-- -----------------------------------------------------------------------------

-- Returns true if the current user belongs to an internal organization
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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.is_internal_user() TO authenticated;

-- -----------------------------------------------------------------------------
-- Check if Current User is Admin
-- -----------------------------------------------------------------------------

-- Returns true if the current user has admin role
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN AS $$
  SELECT auth.user_role() = 'admin';
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.is_admin() IS
  'Returns true if current user has admin role. Used for privileged operations in RLS policies.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.is_admin() TO authenticated;

-- -----------------------------------------------------------------------------
-- Check if Current User is Staff (Admin or Staff Role)
-- -----------------------------------------------------------------------------

-- Returns true if the current user is staff (admin or staff role)
CREATE OR REPLACE FUNCTION auth.is_staff()
RETURNS BOOLEAN AS $$
  SELECT auth.user_role() IN ('admin', 'staff');
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON FUNCTION auth.is_staff() IS
  'Returns true if current user has admin or staff role. Useful for operations allowed to all internal staff.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION auth.is_staff() TO authenticated;

-- =============================================================================
-- USAGE NOTES
-- =============================================================================

-- These helper functions are designed to be used in RLS policies like this:
--
-- Example 1: Customers can only see their own organization's data
-- CREATE POLICY "Customers view own data"
-- ON table_name FOR SELECT
-- USING (
--   auth.is_internal_user() OR
--   organization_id = auth.user_organization_id()
-- );
--
-- Example 2: Only internal staff can create records
-- CREATE POLICY "Staff can create"
-- ON table_name FOR INSERT
-- WITH CHECK (auth.is_internal_user());
--
-- Example 3: Only admins can delete records
-- CREATE POLICY "Admins can delete"
-- ON table_name FOR DELETE
-- USING (auth.is_admin());
--
-- Performance Notes:
-- - All functions are marked STABLE so they're cached per query
-- - SECURITY DEFINER allows functions to access public schema tables
-- - Indexed columns (auth_user_id, organization_id, type) ensure fast lookups
-- - LIMIT 1 prevents unnecessary row scanning
