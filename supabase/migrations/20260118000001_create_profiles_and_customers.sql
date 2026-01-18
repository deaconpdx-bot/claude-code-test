-- Migration: Create Organizations and Users (Profiles and Customers)
-- Description: Sets up the foundational tables for managing internal and customer organizations,
--              along with user profiles linked to Supabase Auth.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column() IS
  'Trigger function to automatically set updated_at to current timestamp on row updates';

-- =============================================================================
-- ORGANIZATIONS TABLE
-- =============================================================================

-- Organizations represent both internal (Stone Forest) and customer organizations
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('internal', 'customer')),
  contact_email VARCHAR(255),
  contact_phone VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add helpful comments
COMMENT ON TABLE organizations IS
  'Stores both internal (Stone Forest) and customer organizations';
COMMENT ON COLUMN organizations.type IS
  'Organization type: internal (Stone Forest staff) or customer (client companies)';
COMMENT ON COLUMN organizations.contact_email IS
  'Primary contact email for the organization';
COMMENT ON COLUMN organizations.contact_phone IS
  'Primary contact phone number for the organization';

-- Create indexes for efficient querying
CREATE INDEX idx_organizations_type ON organizations(type);

COMMENT ON INDEX idx_organizations_type IS
  'Index for filtering organizations by type (internal vs customer)';

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_organizations_updated_at
  BEFORE UPDATE ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- USERS TABLE
-- =============================================================================

-- Users table for application users (internal staff and customer contacts)
-- Links to Supabase Auth via auth_user_id
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

-- Add helpful comments
COMMENT ON TABLE users IS
  'Application users including internal staff and customer contacts';
COMMENT ON COLUMN users.organization_id IS
  'Foreign key to organizations table - each user belongs to one organization';
COMMENT ON COLUMN users.email IS
  'Unique email address for the user - used for login and notifications';
COMMENT ON COLUMN users.role IS
  'User role: admin (full access), staff (internal team), or customer (client users)';
COMMENT ON COLUMN users.auth_user_id IS
  'Link to Supabase Auth user - null if user has not authenticated yet';

-- Create indexes for efficient querying
CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth ON users(auth_user_id);

COMMENT ON INDEX idx_users_organization IS
  'Index for finding all users in an organization';
COMMENT ON INDEX idx_users_email IS
  'Index for email-based user lookups during authentication';
COMMENT ON INDEX idx_users_auth IS
  'Index for linking application users to Supabase Auth users';

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS on both tables (policies will be added in a separate migration)
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE organizations IS
  'Stores both internal (Stone Forest) and customer organizations. RLS enabled.';
COMMENT ON TABLE users IS
  'Application users including internal staff and customer contacts. RLS enabled.';
