-- Migration: Create Proofs and File Assets Tables
-- Description: Sets up tables for managing proof files, versions, and approval workflows.
--              Supports PDF proofs, artwork uploads, and customer approval tracking.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- ENUM TYPES
-- =============================================================================

-- File types for categorizing uploaded files
CREATE TYPE file_type AS ENUM (
  'proof',           -- Proof PDF for customer review
  'artwork',         -- Final artwork files
  'reference',       -- Reference materials
  'attachment'       -- General attachments
);

COMMENT ON TYPE file_type IS
  'Categories for uploaded files: proof (customer review), artwork (final files), reference (materials), attachment (general)';

-- Approval status for proof workflow
CREATE TYPE approval_status AS ENUM (
  'pending',         -- Awaiting customer review
  'approved',        -- Customer approved
  'rejected',        -- Customer rejected (changes needed)
  'revision',        -- Internal revision in progress
  'final'            -- Final approved version
);

COMMENT ON TYPE approval_status IS
  'Proof approval workflow states: pending → approved/rejected → revision → final';

-- =============================================================================
-- FILE ASSETS TABLE
-- =============================================================================

-- Stores all uploaded files (proofs, artwork, attachments)
CREATE TABLE file_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- File metadata
  file_name VARCHAR(255) NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  file_type file_type NOT NULL,
  mime_type VARCHAR(100) NOT NULL,

  -- Storage path (Supabase Storage)
  storage_bucket VARCHAR(100) NOT NULL DEFAULT 'file-assets',
  storage_path VARCHAR(500) NOT NULL,

  -- Version control
  version_number INTEGER NOT NULL DEFAULT 1,
  is_current_version BOOLEAN NOT NULL DEFAULT true,
  parent_file_id UUID REFERENCES file_assets(id) ON DELETE SET NULL,

  -- Approval workflow (for proofs)
  approval_status approval_status,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  rejection_reason TEXT,

  -- Metadata
  uploaded_by UUID NOT NULL REFERENCES users(id),
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add helpful comments
COMMENT ON TABLE file_assets IS
  'Uploaded files including proofs, artwork, and attachments with version control';
COMMENT ON COLUMN file_assets.project_id IS
  'Foreign key to projects - which project this file belongs to';
COMMENT ON COLUMN file_assets.organization_id IS
  'Foreign key to organizations - for RLS data isolation';
COMMENT ON COLUMN file_assets.file_name IS
  'Original filename as uploaded by user';
COMMENT ON COLUMN file_assets.file_size_bytes IS
  'File size in bytes for storage tracking';
COMMENT ON COLUMN file_assets.file_type IS
  'File category: proof, artwork, reference, or attachment';
COMMENT ON COLUMN file_assets.storage_bucket IS
  'Supabase Storage bucket name (default: file-assets)';
COMMENT ON COLUMN file_assets.storage_path IS
  'Path within storage bucket (e.g., project-id/filename-uuid.pdf)';
COMMENT ON COLUMN file_assets.version_number IS
  'Version number for this file (1, 2, 3...)';
COMMENT ON COLUMN file_assets.is_current_version IS
  'True if this is the latest version of the file';
COMMENT ON COLUMN file_assets.parent_file_id IS
  'Link to previous version if this is a revision';
COMMENT ON COLUMN file_assets.approval_status IS
  'Approval state for proofs (null for non-proof files)';
COMMENT ON COLUMN file_assets.approved_by IS
  'User who approved/rejected this proof';
COMMENT ON COLUMN file_assets.approved_at IS
  'Timestamp of approval/rejection';
COMMENT ON COLUMN file_assets.rejection_reason IS
  'Customer feedback if proof was rejected';
COMMENT ON COLUMN file_assets.uploaded_by IS
  'User who uploaded this file';

-- Create indexes for efficient querying
CREATE INDEX idx_file_assets_project ON file_assets(project_id);
CREATE INDEX idx_file_assets_organization ON file_assets(organization_id);
CREATE INDEX idx_file_assets_file_type ON file_assets(file_type);
CREATE INDEX idx_file_assets_approval_status ON file_assets(approval_status);
CREATE INDEX idx_file_assets_is_current ON file_assets(is_current_version) WHERE is_current_version = true;
CREATE INDEX idx_file_assets_parent ON file_assets(parent_file_id);
CREATE INDEX idx_file_assets_uploaded_by ON file_assets(uploaded_by);
CREATE INDEX idx_file_assets_created ON file_assets(created_at DESC);

COMMENT ON INDEX idx_file_assets_project IS
  'Index for finding all files for a specific project';
COMMENT ON INDEX idx_file_assets_organization IS
  'Index for RLS filtering by organization';
COMMENT ON INDEX idx_file_assets_file_type IS
  'Index for filtering by file type (e.g., only proofs)';
COMMENT ON INDEX idx_file_assets_approval_status IS
  'Index for finding proofs by approval status (e.g., pending approvals)';
COMMENT ON INDEX idx_file_assets_is_current IS
  'Partial index for quickly finding current versions only';
COMMENT ON INDEX idx_file_assets_parent IS
  'Index for finding version history chains';
COMMENT ON INDEX idx_file_assets_uploaded_by IS
  'Index for tracking user upload activity';
COMMENT ON INDEX idx_file_assets_created IS
  'Index for chronological sorting (most recent first)';

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_file_assets_updated_at
  BEFORE UPDATE ON file_assets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- APPROVAL EVENTS TABLE
-- =============================================================================

-- Audit log for proof approval workflow events
CREATE TABLE approval_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_asset_id UUID NOT NULL REFERENCES file_assets(id) ON DELETE CASCADE,

  -- Event details
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,

  -- Who triggered this event
  triggered_by UUID REFERENCES users(id),
  triggered_by_system VARCHAR(50),

  -- Email notification tracking
  notification_sent BOOLEAN NOT NULL DEFAULT false,
  notification_sent_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add helpful comments
COMMENT ON TABLE approval_events IS
  'Audit log for proof approval workflow (uploaded, approved, rejected, etc.)';
COMMENT ON COLUMN approval_events.file_asset_id IS
  'Foreign key to file_assets - which file this event is about';
COMMENT ON COLUMN approval_events.event_type IS
  'Event type: uploaded, sent_for_review, approved, rejected, revision_uploaded, etc.';
COMMENT ON COLUMN approval_events.event_data IS
  'Flexible JSON metadata (e.g., rejection comments, email details)';
COMMENT ON COLUMN approval_events.triggered_by IS
  'User who triggered this event (null if system-triggered)';
COMMENT ON COLUMN approval_events.triggered_by_system IS
  'System identifier if automated (e.g., n8n, cron)';
COMMENT ON COLUMN approval_events.notification_sent IS
  'Whether email notification was sent for this event';
COMMENT ON COLUMN approval_events.notification_sent_at IS
  'Timestamp when notification email was sent';

-- Create indexes for efficient querying
CREATE INDEX idx_approval_events_file_asset ON approval_events(file_asset_id);
CREATE INDEX idx_approval_events_type ON approval_events(event_type);
CREATE INDEX idx_approval_events_created ON approval_events(created_at DESC);
CREATE INDEX idx_approval_events_notification ON approval_events(notification_sent) WHERE notification_sent = false;

COMMENT ON INDEX idx_approval_events_file_asset IS
  'Index for finding all events for a specific file';
COMMENT ON INDEX idx_approval_events_type IS
  'Index for filtering by event type';
COMMENT ON INDEX idx_approval_events_created IS
  'Index for chronological sorting';
COMMENT ON INDEX idx_approval_events_notification IS
  'Partial index for finding events that need notification emails sent';

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS (policies will be added in a separate migration)
ALTER TABLE file_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_events ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE file_assets IS
  'Uploaded files including proofs, artwork, and attachments with version control. RLS enabled.';
COMMENT ON TABLE approval_events IS
  'Audit log for proof approval workflow (uploaded, approved, rejected, etc.). RLS enabled.';
