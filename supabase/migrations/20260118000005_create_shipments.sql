-- Migration: Create Shipments Table
-- Description: Sets up shipment tracking for order delivery and logistics.
--              Tracks shipping status, carrier information, and delivery updates.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- ENUM TYPES
-- =============================================================================

-- Shipment status tracking
CREATE TYPE shipment_status AS ENUM (
  'pending',         -- Order received, not yet shipped
  'preparing',       -- Being prepared for shipment
  'shipped',         -- In transit with carrier
  'in_transit',      -- Actively moving in carrier network
  'out_for_delivery',-- Out for final delivery
  'delivered',       -- Successfully delivered
  'failed',          -- Delivery failed (will retry)
  'cancelled',       -- Shipment cancelled
  'returned'         -- Returned to sender
);

COMMENT ON TYPE shipment_status IS
  'Shipment lifecycle: pending → preparing → shipped → in_transit → out_for_delivery → delivered';

-- Shipping carriers
CREATE TYPE shipping_carrier AS ENUM (
  'usps',            -- US Postal Service
  'ups',             -- UPS
  'fedex',           -- FedEx
  'dhl',             -- DHL
  'other',           -- Other carriers
  'hand_delivery'    -- Hand-delivered by staff
);

COMMENT ON TYPE shipping_carrier IS
  'Supported shipping carriers for tracking integration';

-- =============================================================================
-- SHIPMENTS TABLE
-- =============================================================================

-- Tracks shipments for project deliveries
CREATE TABLE shipments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

  -- Shipment details
  shipment_number VARCHAR(50) UNIQUE NOT NULL,
  carrier shipping_carrier NOT NULL,
  tracking_number VARCHAR(100),
  tracking_url VARCHAR(500),

  -- Status tracking
  status shipment_status NOT NULL DEFAULT 'pending',
  status_updated_at TIMESTAMPTZ,

  -- Shipping dates
  expected_ship_date DATE,
  actual_ship_date DATE,
  expected_delivery_date DATE,
  actual_delivery_date DATE,

  -- Shipping addresses
  ship_from_address JSONB,
  ship_to_address JSONB NOT NULL,

  -- Package details
  package_count INTEGER NOT NULL DEFAULT 1,
  weight_lbs DECIMAL(10, 2),
  dimensions_inches VARCHAR(50), -- e.g., "12x8x4"

  -- Cost tracking
  shipping_cost_cents INTEGER,
  insurance_cost_cents INTEGER DEFAULT 0,

  -- Notes and metadata
  notes TEXT,
  internal_notes TEXT, -- Not visible to customers

  -- Tracking
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add helpful comments
COMMENT ON TABLE shipments IS
  'Shipment tracking for project deliveries with carrier integration';
COMMENT ON COLUMN shipments.project_id IS
  'Foreign key to projects - which project this shipment is for';
COMMENT ON COLUMN shipments.organization_id IS
  'Foreign key to organizations - for RLS data isolation';
COMMENT ON COLUMN shipments.shipment_number IS
  'Unique shipment identifier (e.g., SHIP-2026-001)';
COMMENT ON COLUMN shipments.carrier IS
  'Shipping carrier: usps, ups, fedex, dhl, other, hand_delivery';
COMMENT ON COLUMN shipments.tracking_number IS
  'Carrier tracking number for customer lookup';
COMMENT ON COLUMN shipments.tracking_url IS
  'Direct link to carrier tracking page';
COMMENT ON COLUMN shipments.status IS
  'Current shipment status (pending → preparing → shipped → delivered)';
COMMENT ON COLUMN shipments.status_updated_at IS
  'Timestamp of last status change';
COMMENT ON COLUMN shipments.expected_ship_date IS
  'Planned ship date';
COMMENT ON COLUMN shipments.actual_ship_date IS
  'Actual date package was shipped';
COMMENT ON COLUMN shipments.expected_delivery_date IS
  'Estimated delivery date from carrier';
COMMENT ON COLUMN shipments.actual_delivery_date IS
  'Actual delivery date (when status changed to delivered)';
COMMENT ON COLUMN shipments.ship_from_address IS
  'Origin address as JSON (for warehouses/multiple locations)';
COMMENT ON COLUMN shipments.ship_to_address IS
  'Destination address as JSON {street, city, state, zip, country}';
COMMENT ON COLUMN shipments.package_count IS
  'Number of packages in this shipment';
COMMENT ON COLUMN shipments.weight_lbs IS
  'Total weight in pounds';
COMMENT ON COLUMN shipments.dimensions_inches IS
  'Package dimensions as string (e.g., "12x8x4")';
COMMENT ON COLUMN shipments.shipping_cost_cents IS
  'Shipping cost in cents (e.g., $25.99 = 2599)';
COMMENT ON COLUMN shipments.insurance_cost_cents IS
  'Insurance cost in cents';
COMMENT ON COLUMN shipments.notes IS
  'Public notes visible to customer';
COMMENT ON COLUMN shipments.internal_notes IS
  'Internal notes only visible to staff';
COMMENT ON COLUMN shipments.created_by IS
  'Staff member who created this shipment record';

-- Create indexes for efficient querying
CREATE INDEX idx_shipments_project ON shipments(project_id);
CREATE INDEX idx_shipments_organization ON shipments(organization_id);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_carrier ON shipments(carrier);
CREATE INDEX idx_shipments_tracking_number ON shipments(tracking_number);
CREATE INDEX idx_shipments_shipment_number ON shipments(shipment_number);
CREATE INDEX idx_shipments_expected_delivery ON shipments(expected_delivery_date);
CREATE INDEX idx_shipments_actual_delivery ON shipments(actual_delivery_date);
CREATE INDEX idx_shipments_created ON shipments(created_at DESC);

COMMENT ON INDEX idx_shipments_project IS
  'Index for finding all shipments for a specific project';
COMMENT ON INDEX idx_shipments_organization IS
  'Index for RLS filtering by organization';
COMMENT ON INDEX idx_shipments_status IS
  'Index for filtering by shipment status (e.g., in_transit)';
COMMENT ON INDEX idx_shipments_carrier IS
  'Index for filtering by carrier';
COMMENT ON INDEX idx_shipments_tracking_number IS
  'Index for quick tracking number lookup';
COMMENT ON INDEX idx_shipments_shipment_number IS
  'Index for unique shipment number lookup';
COMMENT ON INDEX idx_shipments_expected_delivery IS
  'Index for finding shipments by expected delivery date';
COMMENT ON INDEX idx_shipments_actual_delivery IS
  'Index for delivery date analysis';
COMMENT ON INDEX idx_shipments_created IS
  'Index for chronological sorting';

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_shipments_updated_at
  BEFORE UPDATE ON shipments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- SHIPMENT EVENTS TABLE
-- =============================================================================

-- Audit log for shipment status changes and tracking updates
CREATE TABLE shipment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,

  -- Event details
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB,

  -- Status change tracking
  old_status shipment_status,
  new_status shipment_status,

  -- Location tracking (from carrier updates)
  location VARCHAR(255),
  location_coordinates POINT,

  -- Who triggered this event
  triggered_by UUID REFERENCES users(id),
  triggered_by_system VARCHAR(50),

  -- Notification tracking
  notification_sent BOOLEAN NOT NULL DEFAULT false,
  notification_sent_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add helpful comments
COMMENT ON TABLE shipment_events IS
  'Audit log for shipment tracking updates and status changes';
COMMENT ON COLUMN shipment_events.shipment_id IS
  'Foreign key to shipments - which shipment this event is about';
COMMENT ON COLUMN shipment_events.event_type IS
  'Event type: created, shipped, status_update, delivered, etc.';
COMMENT ON COLUMN shipment_events.event_data IS
  'Flexible JSON metadata (e.g., carrier scan details, delivery signature)';
COMMENT ON COLUMN shipment_events.old_status IS
  'Previous status before this event';
COMMENT ON COLUMN shipment_events.new_status IS
  'New status after this event';
COMMENT ON COLUMN shipment_events.location IS
  'Location description from carrier (e.g., "Denver, CO")';
COMMENT ON COLUMN shipment_events.location_coordinates IS
  'GPS coordinates if available from carrier';
COMMENT ON COLUMN shipment_events.triggered_by IS
  'User who triggered this event (null if system/carrier update)';
COMMENT ON COLUMN shipment_events.triggered_by_system IS
  'System identifier if automated (e.g., n8n, carrier_webhook)';
COMMENT ON COLUMN shipment_events.notification_sent IS
  'Whether customer was notified of this event';
COMMENT ON COLUMN shipment_events.notification_sent_at IS
  'Timestamp when notification was sent';

-- Create indexes for efficient querying
CREATE INDEX idx_shipment_events_shipment ON shipment_events(shipment_id);
CREATE INDEX idx_shipment_events_type ON shipment_events(event_type);
CREATE INDEX idx_shipment_events_created ON shipment_events(created_at DESC);
CREATE INDEX idx_shipment_events_notification ON shipment_events(notification_sent) WHERE notification_sent = false;
CREATE INDEX idx_shipment_events_status_change ON shipment_events(new_status) WHERE new_status IS NOT NULL;

COMMENT ON INDEX idx_shipment_events_shipment IS
  'Index for finding all events for a specific shipment';
COMMENT ON INDEX idx_shipment_events_type IS
  'Index for filtering by event type';
COMMENT ON INDEX idx_shipment_events_created IS
  'Index for chronological sorting';
COMMENT ON INDEX idx_shipment_events_notification IS
  'Partial index for finding events needing notifications';
COMMENT ON INDEX idx_shipment_events_status_change IS
  'Partial index for status change events only';

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

-- Enable RLS (policies will be added in a separate migration)
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_events ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE shipments IS
  'Shipment tracking for project deliveries with carrier integration. RLS enabled.';
COMMENT ON TABLE shipment_events IS
  'Audit log for shipment tracking updates and status changes. RLS enabled.';
