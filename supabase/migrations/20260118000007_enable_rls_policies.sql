-- Migration: Enable Row Level Security Policies
-- Description: Creates RLS policies for all tables to enforce data isolation between
--              customers and provide full access to internal staff.
--              Uses helper functions defined in migration 006.
-- Sprint: 002A - Supabase Foundation

-- Note: This migration depends on helper functions from 20260118000006_create_rls_helpers.sql
-- Functions used: auth.user_organization_id(), auth.is_internal_user(), auth.user_role()

-- =============================================================================
-- ORGANIZATIONS TABLE POLICIES
-- =============================================================================

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

COMMENT ON POLICY "Internal users can view all organizations" ON organizations IS
  'Internal staff can see all organizations (customers and internal)';
COMMENT ON POLICY "Customers can view their organization" ON organizations IS
  'Customer users can only see their own organization details';
COMMENT ON POLICY "Admins can manage organizations" ON organizations IS
  'Only admin users can create, update, or delete organizations';

-- =============================================================================
-- USERS TABLE POLICIES
-- =============================================================================

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

COMMENT ON POLICY "Internal users can view all users" ON users IS
  'Internal staff can see all users across all organizations';
COMMENT ON POLICY "Customers can view their organization users" ON users IS
  'Customer users can see other users in their organization';
COMMENT ON POLICY "Users can update own profile" ON users IS
  'Users can update their own profile information (name, email, etc.)';
COMMENT ON POLICY "Admins and staff can manage users" ON users IS
  'Admin and staff users can create, update, or delete any user';

-- =============================================================================
-- PROJECTS TABLE POLICIES
-- =============================================================================

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

-- Internal staff can create and update projects
CREATE POLICY "Internal users can create projects"
ON projects FOR INSERT
WITH CHECK (auth.is_internal_user());

CREATE POLICY "Internal users can update projects"
ON projects FOR UPDATE
USING (auth.is_internal_user())
WITH CHECK (auth.is_internal_user());

-- Only admins can delete projects
CREATE POLICY "Admins can delete projects"
ON projects FOR DELETE
USING (auth.user_role() = 'admin');

COMMENT ON POLICY "Internal users can view all projects" ON projects IS
  'Internal staff can see all customer projects';
COMMENT ON POLICY "Customers can view their projects" ON projects IS
  'Customers can only see projects belonging to their organization';
COMMENT ON POLICY "Internal users can create projects" ON projects IS
  'Internal staff can create new projects for any customer';
COMMENT ON POLICY "Internal users can update projects" ON projects IS
  'Internal staff can update project details';
COMMENT ON POLICY "Admins can delete projects" ON projects IS
  'Only admins can delete projects (rare operation)';

-- =============================================================================
-- INVOICES TABLE POLICIES
-- =============================================================================

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

COMMENT ON POLICY "Internal users can view all invoices" ON invoices IS
  'Internal staff can see all invoices including drafts';
COMMENT ON POLICY "Customers can view their invoices" ON invoices IS
  'Customers can see their invoices but not draft invoices';
COMMENT ON POLICY "Internal users can create invoices" ON invoices IS
  'Only internal staff can create new invoices';
COMMENT ON POLICY "Internal users can update invoices" ON invoices IS
  'Only internal staff can update invoice details and status';
COMMENT ON POLICY "Admins can delete invoices" ON invoices IS
  'Only admins can delete invoices (for corrections)';

-- =============================================================================
-- INVOICE_EVENTS TABLE POLICIES
-- =============================================================================

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
    AND invoices.status != 'draft'
  )
);

-- Internal users can manually create events
CREATE POLICY "Internal users can create invoice events"
ON invoice_events FOR INSERT
WITH CHECK (auth.is_internal_user());

-- No updates or deletes allowed (audit log is append-only)
-- Admins can delete via service role if absolutely necessary

COMMENT ON POLICY "Internal users can view all invoice events" ON invoice_events IS
  'Internal staff can see all invoice events across all customers';
COMMENT ON POLICY "Customers can view their invoice events" ON invoice_events IS
  'Customers can see events for their non-draft invoices';
COMMENT ON POLICY "Internal users can create invoice events" ON invoice_events IS
  'Internal staff can manually log invoice events';

-- =============================================================================
-- FILE_ASSETS TABLE POLICIES (Proofs and Files)
-- =============================================================================

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

-- Internal users can create and update file assets
CREATE POLICY "Internal users can create file assets"
ON file_assets FOR INSERT
WITH CHECK (auth.is_internal_user());

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

COMMENT ON POLICY "Internal users can view all file assets" ON file_assets IS
  'Internal staff can see all file assets across all projects';
COMMENT ON POLICY "Customers can view their file assets" ON file_assets IS
  'Customers can see file assets for their organization';
COMMENT ON POLICY "Internal users can create file assets" ON file_assets IS
  'Internal staff can upload new files including proofs';
COMMENT ON POLICY "Internal users can update file assets" ON file_assets IS
  'Internal staff can update file details and metadata';
COMMENT ON POLICY "Customers can update file asset approvals" ON file_assets IS
  'Customers can approve or reject proofs for their projects';
COMMENT ON POLICY "Admins can delete file assets" ON file_assets IS
  'Only admins can delete file assets';

-- =============================================================================
-- APPROVAL_EVENTS TABLE POLICIES
-- =============================================================================

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

COMMENT ON POLICY "Internal users can view all approval events" ON approval_events IS
  'Internal staff can see all approval events';
COMMENT ON POLICY "Customers can view their approval events" ON approval_events IS
  'Customers can see approval events for their files';
COMMENT ON POLICY "Internal users can create approval events" ON approval_events IS
  'Internal staff can log approval events';

-- =============================================================================
-- SHIPMENTS TABLE POLICIES
-- =============================================================================

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

-- Internal users can create and update shipments
CREATE POLICY "Internal users can create shipments"
ON shipments FOR INSERT
WITH CHECK (auth.is_internal_user());

CREATE POLICY "Internal users can update shipments"
ON shipments FOR UPDATE
USING (auth.is_internal_user())
WITH CHECK (auth.is_internal_user());

-- Only admins can delete shipments
CREATE POLICY "Admins can delete shipments"
ON shipments FOR DELETE
USING (auth.user_role() = 'admin');

COMMENT ON POLICY "Internal users can view all shipments" ON shipments IS
  'Internal staff can see all shipments across all projects';
COMMENT ON POLICY "Customers can view their shipments" ON shipments IS
  'Customers can see shipments for their organization';
COMMENT ON POLICY "Internal users can create shipments" ON shipments IS
  'Internal staff can create shipment records';
COMMENT ON POLICY "Internal users can update shipments" ON shipments IS
  'Internal staff can update tracking information and delivery status';
COMMENT ON POLICY "Admins can delete shipments" ON shipments IS
  'Only admins can delete shipment records';

-- =============================================================================
-- SHIPMENT_EVENTS TABLE POLICIES
-- =============================================================================

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

COMMENT ON POLICY "Internal users can view all shipment events" ON shipment_events IS
  'Internal staff can see all shipment tracking events';
COMMENT ON POLICY "Customers can view their shipment events" ON shipment_events IS
  'Customers can see tracking events for their shipments';
COMMENT ON POLICY "Internal users can create shipment events" ON shipment_events IS
  'Internal staff can log shipment tracking events';
