-- Migration: Create Projects Table
-- Description: Sets up the projects table for managing customer print jobs, design work, etc.
--              Projects link to organizations and track work status.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- PROJECTS TABLE
-- =============================================================================

-- Projects represent customer work (print jobs, design projects, etc.)
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

-- Add helpful comments
COMMENT ON TABLE projects IS
  'Customer projects including print jobs, design work, and other services';
COMMENT ON COLUMN projects.organization_id IS
  'Foreign key to organizations - which customer this project belongs to';
COMMENT ON COLUMN projects.name IS
  'Project name/title (e.g., "Q1 2026 Product Catalog")';
COMMENT ON COLUMN projects.description IS
  'Detailed description of project scope and requirements';
COMMENT ON COLUMN projects.status IS
  'Current project status: active (in progress), on_hold (paused), completed (finished), cancelled (abandoned)';
COMMENT ON COLUMN projects.created_by IS
  'Foreign key to users - which staff member created this project';

-- Create indexes for efficient querying
CREATE INDEX idx_projects_organization ON projects(organization_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_created_by ON projects(created_by);

COMMENT ON INDEX idx_projects_organization IS
  'Index for finding all projects for a specific customer organization';
COMMENT ON INDEX idx_projects_status IS
  'Index for filtering projects by status (e.g., all active projects)';
COMMENT ON INDEX idx_projects_created_by IS
  'Index for tracking which staff member created each project';

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS (policies will be added in a separate migration)
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE projects IS
  'Customer projects including print jobs, design work, and other services. RLS enabled.';
