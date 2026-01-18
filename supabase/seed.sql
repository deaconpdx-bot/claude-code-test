-- =============================================================================
-- SEED DATA FOR STONE FOREST APP
-- =============================================================================
-- Description: Sample data for development and testing
-- Sprint: 002A - Supabase Foundation
--
-- WARNING: This file will DELETE ALL EXISTING DATA
-- Only run this in development/staging environments!
-- =============================================================================

BEGIN;

-- Clean up existing data (in reverse order of dependencies)
TRUNCATE TABLE shipment_events CASCADE;
TRUNCATE TABLE approval_events CASCADE;
TRUNCATE TABLE invoice_events CASCADE;
TRUNCATE TABLE shipments CASCADE;
TRUNCATE TABLE file_assets CASCADE;
TRUNCATE TABLE invoices CASCADE;
TRUNCATE TABLE projects CASCADE;
TRUNCATE TABLE users CASCADE;
TRUNCATE TABLE organizations CASCADE;

-- =============================================================================
-- ORGANIZATIONS
-- =============================================================================

-- Internal organization (Stone Forest)
INSERT INTO organizations (id, name, type, contact_email, contact_phone, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Stone Forest', 'internal', 'info@stoneforest.com', '555-0100', NOW(), NOW());

-- Customer organizations
INSERT INTO organizations (id, name, type, contact_email, contact_phone, created_at, updated_at)
VALUES
  ('org-customer-001', 'ACME Corp', 'customer', 'billing@acmecorp.com', '555-0201', NOW() - INTERVAL '180 days', NOW()),
  ('org-customer-002', 'TechStart Inc', 'customer', 'accounts@techstart.io', '555-0202', NOW() - INTERVAL '90 days', NOW()),
  ('org-customer-003', 'Global Retail Co', 'customer', 'ap@globalretail.com', '555-0203', NOW() - INTERVAL '60 days', NOW());

-- =============================================================================
-- USERS
-- =============================================================================

-- Internal users (Stone Forest staff)
INSERT INTO users (id, organization_id, email, name, role, auth_user_id, created_at, updated_at)
VALUES
  ('user-admin-001', '00000000-0000-0000-0000-000000000001', 'admin@stoneforest.com', 'Admin User', 'admin', NULL, NOW(), NOW()),
  ('user-staff-001', '00000000-0000-0000-0000-000000000001', 'sarah@stoneforest.com', 'Sarah Chen', 'staff', NULL, NOW(), NOW()),
  ('user-staff-002', '00000000-0000-0000-0000-000000000001', 'mike@stoneforest.com', 'Mike Thompson', 'staff', NULL, NOW(), NOW()),
  ('user-staff-003', '00000000-0000-0000-0000-000000000001', 'lisa@stoneforest.com', 'Lisa Rodriguez', 'staff', NULL, NOW(), NOW());

-- Customer users
INSERT INTO users (id, organization_id, email, name, role, auth_user_id, created_at, updated_at)
VALUES
  ('user-customer-001', 'org-customer-001', 'john.doe@acmecorp.com', 'John Doe', 'customer', NULL, NOW() - INTERVAL '180 days', NOW()),
  ('user-customer-002', 'org-customer-001', 'jane.smith@acmecorp.com', 'Jane Smith', 'customer', NULL, NOW() - INTERVAL '170 days', NOW()),
  ('user-customer-003', 'org-customer-002', 'alex@techstart.io', 'Alex Kumar', 'customer', NULL, NOW() - INTERVAL '90 days', NOW()),
  ('user-customer-004', 'org-customer-003', 'maria@globalretail.com', 'Maria Garcia', 'customer', NULL, NOW() - INTERVAL '60 days', NOW());

-- =============================================================================
-- PROJECTS
-- =============================================================================

INSERT INTO projects (id, organization_id, name, description, status, created_by, created_at, updated_at)
VALUES
  -- ACME Corp projects
  ('proj-001', 'org-customer-001', 'Product Catalog Q1 2026', 'Full-color catalog with 500 units', 'active', 'user-staff-001', '2025-12-01 10:00:00+00', NOW()),
  ('proj-002', 'org-customer-001', 'Marketing Brochures', 'Tri-fold brochures for trade show - rush order', 'completed', 'user-staff-002', '2025-12-10 14:30:00+00', NOW()),
  ('proj-003', 'org-customer-001', 'Event Posters', 'Large format posters for annual conference', 'active', 'user-staff-001', '2025-12-15 09:00:00+00', NOW()),
  ('proj-004', 'org-customer-001', 'Window Graphics', 'Retail window displays - multiple locations', 'active', 'user-staff-003', '2026-01-05 11:00:00+00', NOW()),
  ('proj-005', 'org-customer-001', 'Business Cards Reprint', 'Standard business cards for new employees', 'active', 'user-staff-002', '2026-01-08 15:00:00+00', NOW()),

  -- TechStart Inc projects
  ('proj-006', 'org-customer-002', 'Startup Pitch Deck Printing', 'Premium presentation folders and inserts', 'active', 'user-staff-001', '2025-11-20 10:00:00+00', NOW()),
  ('proj-007', 'org-customer-002', 'Trade Show Banners', 'Retractable banners for tech conference', 'completed', 'user-staff-003', '2025-12-15 13:00:00+00', NOW()),

  -- Global Retail Co projects
  ('proj-008', 'org-customer-003', 'Signage Maintenance', 'Repair and update existing store signage', 'active', 'user-staff-002', '2025-12-20 09:30:00+00', NOW()),
  ('proj-009', 'org-customer-003', 'Holiday Promotional Materials', 'Seasonal displays and banners', 'completed', 'user-staff-001', '2025-11-01 10:00:00+00', NOW());

-- =============================================================================
-- INVOICES
-- =============================================================================

INSERT INTO invoices (
  id, project_id, organization_id, invoice_number, issue_date, due_date,
  amount_subtotal, amount_tax, amount_total, amount_paid,
  deposit_required, deposit_amount, deposit_paid, deposit_paid_at,
  status, notes, created_by, created_at, updated_at
)
VALUES
  -- INV-2026-001: Sent, unpaid, deposit required (ACTIONABLE)
  (
    'inv-001', 'proj-001', 'org-customer-001', 'INV-2026-001',
    '2026-01-10', '2026-02-10',
    50000, 5000, 55000, 0,
    true, 27500, false, NULL,
    'sent', 'Product Catalog Q1 2026 - 500 units',
    'user-staff-001', '2026-01-10 09:00:00+00', NOW()
  ),

  -- INV-2026-002: Paid in full
  (
    'inv-002', 'proj-002', 'org-customer-001', 'INV-2026-002',
    '2025-12-15', '2026-01-15',
    25000, 2500, 27500, 27500,
    false, NULL, false, NULL,
    'paid', 'Marketing brochures - rush order',
    'user-staff-002', '2025-12-15 10:00:00+00', NOW()
  ),

  -- INV-2026-003: Overdue, deposit paid, balance due (ACTIONABLE)
  (
    'inv-003', 'proj-003', 'org-customer-001', 'INV-2026-003',
    '2026-01-01', '2026-01-14',
    75000, 7500, 82500, 41250,
    true, 41250, true, '2026-01-02 10:30:00+00',
    'overdue', 'Event posters - deposit paid, balance overdue',
    'user-staff-001', '2026-01-01 14:00:00+00', NOW()
  ),

  -- INV-2026-004: Sent, unpaid, deposit required (ACTIONABLE)
  (
    'inv-004', 'proj-004', 'org-customer-001', 'INV-2026-004',
    '2026-01-12', '2026-01-22',
    120000, 12000, 132000, 0,
    true, 66000, false, NULL,
    'sent', 'Window graphics - deposit required before printing',
    'user-staff-003', '2026-01-12 11:00:00+00', NOW()
  ),

  -- INV-2026-005: Sent, due today (ACTIONABLE - simulate due today)
  (
    'inv-005', 'proj-005', 'org-customer-001', 'INV-2026-005',
    CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE,
    35000, 3500, 38500, 0,
    false, NULL, false, NULL,
    'sent', 'Business cards reprint',
    'user-staff-002', CURRENT_DATE - INTERVAL '3 days', NOW()
  ),

  -- INV-2026-006: Paid in full, deposit was required and paid
  (
    'inv-006', 'proj-007', 'org-customer-002', 'INV-2026-006',
    '2026-01-05', '2026-02-05',
    95000, 9500, 104500, 104500,
    true, 52250, true, '2026-01-06 14:20:00+00',
    'paid', 'Trade show banners - paid in full',
    'user-staff-003', '2026-01-05 09:00:00+00', NOW()
  ),

  -- INV-2026-007: Sent, due in 4 days (ACTIONABLE - due soon)
  (
    'inv-007', 'proj-008', 'org-customer-003', 'INV-2026-007',
    CURRENT_DATE - INTERVAL '10 days', CURRENT_DATE + INTERVAL '4 days',
    42000, 4200, 46200, 0,
    false, NULL, false, NULL,
    'sent', 'Signage repair and maintenance',
    'user-staff-002', CURRENT_DATE - INTERVAL '10 days', NOW()
  ),

  -- INV-2026-008: Paid
  (
    'inv-008', 'proj-009', 'org-customer-003', 'INV-2026-008',
    '2025-12-20', '2026-01-20',
    68000, 6800, 74800, 74800,
    false, NULL, false, NULL,
    'paid', 'Holiday promotional materials',
    'user-staff-001', '2025-12-20 10:00:00+00', NOW()
  ),

  -- INV-2026-009: Draft (not visible to customer)
  (
    'inv-009', 'proj-006', 'org-customer-002', 'INV-2026-009',
    CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
    45000, 4500, 49500, 0,
    false, NULL, false, NULL,
    'draft', 'Startup pitch deck printing - awaiting final approval',
    'user-staff-001', CURRENT_DATE, NOW()
  );

-- =============================================================================
-- INVOICE EVENTS
-- =============================================================================

INSERT INTO invoice_events (id, invoice_id, event_type, event_data, triggered_by, triggered_by_system, created_at)
VALUES
  -- INV-2026-001 events
  ('evt-001', 'inv-001', 'created', '{"created_by": "Sarah Chen"}', 'user-staff-001', NULL, '2026-01-10 09:00:00+00'),
  ('evt-002', 'inv-001', 'sent', '{"sent_to": "billing@acmecorp.com", "method": "email"}', 'user-staff-001', NULL, '2026-01-10 09:15:00+00'),

  -- INV-2026-002 events (paid)
  ('evt-003', 'inv-002', 'created', '{"created_by": "Mike Thompson"}', 'user-staff-002', NULL, '2025-12-15 10:00:00+00'),
  ('evt-004', 'inv-002', 'sent', '{"sent_to": "billing@acmecorp.com", "method": "email"}', 'user-staff-002', NULL, '2025-12-15 10:30:00+00'),
  ('evt-005', 'inv-002', 'payment_received', '{"amount": 27500, "payment_method": "check", "check_number": "1234"}', 'user-staff-002', NULL, '2026-01-10 14:00:00+00'),

  -- INV-2026-003 events (overdue)
  ('evt-006', 'inv-003', 'created', '{"created_by": "Sarah Chen"}', 'user-staff-001', NULL, '2026-01-01 14:00:00+00'),
  ('evt-007', 'inv-003', 'sent', '{"sent_to": "billing@acmecorp.com", "method": "email"}', 'user-staff-001', NULL, '2026-01-01 14:30:00+00'),
  ('evt-008', 'inv-003', 'deposit_received', '{"amount": 41250, "payment_method": "stripe", "transaction_id": "ch_abc123"}', 'user-staff-001', NULL, '2026-01-02 10:30:00+00'),
  ('evt-009', 'inv-003', 'reminder_7day', '{"days_until_due": 7, "amount_due": 41250, "email_sent_to": "billing@acmecorp.com", "n8n_workflow_id": "workflow-123"}', NULL, 'n8n', '2026-01-07 09:00:00+00'),
  ('evt-010', 'inv-003', 'reminder_due', '{"days_until_due": 0, "amount_due": 41250, "email_sent_to": "billing@acmecorp.com"}', NULL, 'n8n', '2026-01-14 09:00:00+00'),
  ('evt-011', 'inv-003', 'marked_overdue', '{"previous_status": "sent", "days_overdue": 1}', NULL, 'n8n', '2026-01-15 00:01:00+00'),
  ('evt-012', 'inv-003', 'reminder_overdue', '{"days_overdue": 3, "amount_due": 41250, "email_sent_to": "billing@acmecorp.com"}', NULL, 'n8n', '2026-01-17 09:00:00+00'),

  -- INV-2026-006 events (paid with deposit)
  ('evt-013', 'inv-006', 'created', '{"created_by": "Lisa Rodriguez"}', 'user-staff-003', NULL, '2026-01-05 09:00:00+00'),
  ('evt-014', 'inv-006', 'sent', '{"sent_to": "accounts@techstart.io", "method": "email"}', 'user-staff-003', NULL, '2026-01-05 09:30:00+00'),
  ('evt-015', 'inv-006', 'deposit_received', '{"amount": 52250, "payment_method": "stripe", "transaction_id": "ch_def456"}', 'user-staff-003', NULL, '2026-01-06 14:20:00+00'),
  ('evt-016', 'inv-006', 'payment_received', '{"amount": 52250, "payment_method": "stripe", "transaction_id": "ch_ghi789", "note": "Final payment"}', 'user-staff-003', NULL, '2026-01-15 11:00:00+00'),

  -- INV-2026-008 events (paid)
  ('evt-017', 'inv-008', 'created', '{"created_by": "Sarah Chen"}', 'user-staff-001', NULL, '2025-12-20 10:00:00+00'),
  ('evt-018', 'inv-008', 'sent', '{"sent_to": "ap@globalretail.com", "method": "email"}', 'user-staff-001', NULL, '2025-12-20 10:30:00+00'),
  ('evt-019', 'inv-008', 'payment_received', '{"amount": 74800, "payment_method": "ach", "note": "ACH transfer"}', 'user-staff-001', NULL, '2026-01-05 09:00:00+00');

-- =============================================================================
-- FILE ASSETS (Proofs)
-- =============================================================================

INSERT INTO file_assets (
  id, project_id, organization_id, file_name, file_size_bytes, file_type, mime_type,
  storage_bucket, storage_path, version_number, is_current_version, parent_file_id,
  approval_status, approved_by, approved_at, rejection_reason,
  uploaded_by, notes, created_at, updated_at
)
VALUES
  -- Product Catalog - approved version 1
  (
    'file-001', 'proj-001', 'org-customer-001',
    'product-catalog-q1-2026-proof-v1.pdf', 2457600, 'proof', 'application/pdf',
    'file-assets', 'proj-001/product-catalog-q1-2026-proof-v1.pdf',
    1, false, NULL,
    'approved', 'user-customer-001', '2025-12-06 14:30:00+00', NULL,
    'user-staff-001', 'Initial proof for customer review',
    '2025-12-05 10:00:00+00', NOW()
  ),

  -- Product Catalog - pending version 2 (ACTIONABLE - old pending proof)
  (
    'file-002', 'proj-001', 'org-customer-001',
    'product-catalog-q1-2026-proof-v2.pdf', 2598400, 'proof', 'application/pdf',
    'file-assets', 'proj-001/product-catalog-q1-2026-proof-v2.pdf',
    2, true, 'file-001',
    'pending', NULL, NULL, NULL,
    'user-staff-001', 'Revised proof with updated pricing',
    '2026-01-08 11:00:00+00', NOW()
  ),

  -- Marketing Brochures - approved
  (
    'file-003', 'proj-002', 'org-customer-001',
    'marketing-brochures-proof.pdf', 1048576, 'proof', 'application/pdf',
    'file-assets', 'proj-002/marketing-brochures-proof.pdf',
    1, true, NULL,
    'approved', 'user-customer-001', '2025-12-12 16:00:00+00', NULL,
    'user-staff-002', 'Rush order proof',
    '2025-12-12 09:00:00+00', NOW()
  ),

  -- Event Posters - rejected version 1
  (
    'file-004', 'proj-003', 'org-customer-001',
    'event-posters-v1.pdf', 3145728, 'proof', 'application/pdf',
    'file-assets', 'proj-003/event-posters-v1.pdf',
    1, false, NULL,
    'rejected', 'user-customer-001', '2025-12-19 15:00:00+00',
    'Please adjust the logo size and fix typo on page 2.',
    'user-staff-001', 'Initial conference poster proof',
    '2025-12-18 10:00:00+00', NOW()
  ),

  -- Event Posters - approved version 2
  (
    'file-005', 'proj-003', 'org-customer-001',
    'event-posters-v2.pdf', 3145728, 'proof', 'application/pdf',
    'file-assets', 'proj-003/event-posters-v2.pdf',
    2, true, 'file-004',
    'approved', 'user-customer-001', '2025-12-20 14:00:00+00', NULL,
    'user-staff-001', 'Corrected version with all requested changes',
    '2025-12-20 11:00:00+00', NOW()
  ),

  -- Window Graphics - pending review (ACTIONABLE - 5 days old)
  (
    'file-006', 'proj-004', 'org-customer-001',
    'window-graphics-proof.pdf', 4194304, 'proof', 'application/pdf',
    'file-assets', 'proj-004/window-graphics-proof.pdf',
    1, true, NULL,
    'pending', NULL, NULL, NULL,
    'user-staff-003', 'Retail window display designs for multiple locations',
    CURRENT_DATE - INTERVAL '5 days', NOW()
  ),

  -- Trade Show Banners - approved
  (
    'file-007', 'proj-007', 'org-customer-002',
    'trade-show-banners.pdf', 1572864, 'proof', 'application/pdf',
    'file-assets', 'proj-007/trade-show-banners.pdf',
    1, true, NULL,
    'approved', 'user-customer-003', '2025-12-19 10:00:00+00', NULL,
    'user-staff-003', 'Retractable banner designs',
    '2025-12-18 13:00:00+00', NOW()
  ),

  -- Additional artwork file (not a proof)
  (
    'file-008', 'proj-001', 'org-customer-001',
    'catalog-source-artwork.ai', 52428800, 'artwork', 'application/illustrator',
    'file-assets', 'proj-001/catalog-source-artwork.ai',
    1, true, NULL,
    NULL, NULL, NULL, NULL,
    'user-customer-001', 'Source artwork files from client',
    '2025-12-01 14:00:00+00', NOW()
  );

-- =============================================================================
-- SHIPMENTS
-- =============================================================================

INSERT INTO shipments (
  id, project_id, organization_id, shipment_number, carrier, tracking_number, tracking_url,
  status, status_updated_at,
  expected_ship_date, actual_ship_date, expected_delivery_date, actual_delivery_date,
  ship_from_address, ship_to_address,
  package_count, weight_lbs, dimensions_inches,
  shipping_cost_cents, insurance_cost_cents,
  notes, internal_notes,
  created_by, created_at, updated_at
)
VALUES
  -- Marketing Brochures - delivered
  (
    'ship-001', 'proj-002', 'org-customer-001',
    'SHIP-2025-001', 'ups', '1Z999AA10123456784', 'https://www.ups.com/track?tracknum=1Z999AA10123456784',
    'delivered', '2025-12-23 14:30:00+00',
    '2025-12-20', '2025-12-20', '2025-12-23', '2025-12-23',
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "123 Business Park Dr", "city": "San Francisco", "state": "CA", "zip": "94102", "country": "US", "contact_name": "Jane Smith"}'::jsonb,
    2, 15.5, '18x12x6',
    1599, 0,
    'Rush order - delivered on time', NULL,
    'user-staff-002', '2025-12-20 08:00:00+00', NOW()
  ),

  -- Event Posters - delivered
  (
    'ship-002', 'proj-003', 'org-customer-001',
    'SHIP-2025-002', 'fedex', '781234567890', 'https://www.fedex.com/fedextrack/?tracknumbers=781234567890',
    'delivered', '2026-01-02 11:15:00+00',
    '2025-12-28', '2025-12-28', '2026-01-02', '2026-01-02',
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "456 Convention Center Blvd", "city": "Las Vegas", "state": "NV", "zip": "89109", "country": "US", "contact_name": "John Doe"}'::jsonb,
    1, 42.0, '48x36x4',
    3599, 500,
    'Conference venue delivery', 'Signature required',
    'user-staff-001', '2025-12-28 10:00:00+00', NOW()
  ),

  -- Trade Show Banners - delivered
  (
    'ship-003', 'proj-007', 'org-customer-002',
    'SHIP-2026-001', 'ups', '1Z999AA10987654321', 'https://www.ups.com/track?tracknum=1Z999AA10987654321',
    'delivered', '2026-01-06 15:45:00+00',
    '2026-01-02', '2026-01-02', '2026-01-06', '2026-01-06',
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "789 Tech Campus Way", "city": "Austin", "state": "TX", "zip": "78701", "country": "US", "contact_name": "Alex Kumar"}'::jsonb,
    3, 28.0, '12x12x48',
    2999, 0,
    'Tech conference materials', NULL,
    'user-staff-003', '2026-01-02 09:00:00+00', NOW()
  ),

  -- Holiday Promo Materials - delivered
  (
    'ship-004', 'proj-009', 'org-customer-003',
    'SHIP-2025-003', 'fedex', '781234567891', 'https://www.fedex.com/fedextrack/?tracknumbers=781234567891',
    'delivered', '2025-11-19 16:20:00+00',
    '2025-11-15', '2025-11-15', '2025-11-20', '2025-11-19',
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "100 Retail Plaza", "city": "New York", "state": "NY", "zip": "10001", "country": "US", "contact_name": "Maria Garcia"}'::jsonb,
    5, 65.0, '24x18x12',
    4599, 1000,
    'Holiday season materials - early delivery', NULL,
    'user-staff-001', '2025-11-15 08:00:00+00', NOW()
  ),

  -- Product Catalog - in transit (ACTIONABLE - no tracking number, old shipment)
  (
    'ship-005', 'proj-001', 'org-customer-001',
    'SHIP-2026-002', 'usps', NULL, NULL,
    'in_transit', CURRENT_DATE - INTERVAL '3 days',
    CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE - INTERVAL '3 days',
    CURRENT_DATE + INTERVAL '2 days', NULL,
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "123 Business Park Dr", "city": "San Francisco", "state": "CA", "zip": "94102", "country": "US", "contact_name": "John Doe"}'::jsonb,
    1, 8.0, '12x9x3',
    899, 0,
    'Sample copies shipped', 'Tracking number not yet available from USPS',
    'user-staff-001', CURRENT_DATE - INTERVAL '3 days', NOW()
  ),

  -- Signage Maintenance - in transit, due tomorrow (ACTIONABLE - ETA risk)
  (
    'ship-006', 'proj-008', 'org-customer-003',
    'SHIP-2026-003', 'ups', '1Z999AA10555666777', 'https://www.ups.com/track?tracknum=1Z999AA10555666777',
    'in_transit', CURRENT_DATE - INTERVAL '2 days',
    CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE - INTERVAL '2 days',
    CURRENT_DATE + INTERVAL '1 day', NULL,
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "100 Retail Plaza", "city": "New York", "state": "NY", "zip": "10001", "country": "US", "contact_name": "Maria Garcia"}'::jsonb,
    2, 22.5, '36x24x6',
    3299, 250,
    'Replacement signage parts - customer needs by tomorrow', 'Monitor closely - tight deadline',
    'user-staff-002', CURRENT_DATE - INTERVAL '2 days', NOW()
  ),

  -- Window Graphics - not yet shipped (waiting for deposit)
  (
    'ship-007', 'proj-004', 'org-customer-001',
    'SHIP-2026-004', 'other', NULL, NULL,
    'pending', '2026-01-12 11:00:00+00',
    '2026-01-22', NULL, '2026-01-27', NULL,
    '{"street": "1000 Stone Forest Way", "city": "Portland", "state": "OR", "zip": "97201", "country": "US"}'::jsonb,
    '{"street": "789 Market Street", "city": "San Francisco", "state": "CA", "zip": "94103", "country": "US", "contact_name": "John Doe"}'::jsonb,
    4, 85.0, '48x36x8',
    5999, 500,
    'Awaiting deposit payment before shipping', 'Large order - multiple locations',
    'user-staff-003', '2026-01-12 11:00:00+00', NOW()
  );

COMMIT;

-- =============================================================================
-- VERIFY DATA
-- =============================================================================

-- Show summary of seeded data
DO $$
BEGIN
  RAISE NOTICE '=============================================================================';
  RAISE NOTICE 'SEED DATA SUMMARY';
  RAISE NOTICE '=============================================================================';
  RAISE NOTICE 'Organizations: %', (SELECT COUNT(*) FROM organizations);
  RAISE NOTICE '  - Internal: %', (SELECT COUNT(*) FROM organizations WHERE type = 'internal');
  RAISE NOTICE '  - Customers: %', (SELECT COUNT(*) FROM organizations WHERE type = 'customer');
  RAISE NOTICE '';
  RAISE NOTICE 'Users: %', (SELECT COUNT(*) FROM users);
  RAISE NOTICE '  - Admins: %', (SELECT COUNT(*) FROM users WHERE role = 'admin');
  RAISE NOTICE '  - Staff: %', (SELECT COUNT(*) FROM users WHERE role = 'staff');
  RAISE NOTICE '  - Customers: %', (SELECT COUNT(*) FROM users WHERE role = 'customer');
  RAISE NOTICE '';
  RAISE NOTICE 'Projects: %', (SELECT COUNT(*) FROM projects);
  RAISE NOTICE '  - Active: %', (SELECT COUNT(*) FROM projects WHERE status = 'active');
  RAISE NOTICE '  - Completed: %', (SELECT COUNT(*) FROM projects WHERE status = 'completed');
  RAISE NOTICE '';
  RAISE NOTICE 'Invoices: %', (SELECT COUNT(*) FROM invoices);
  RAISE NOTICE '  - Draft: %', (SELECT COUNT(*) FROM invoices WHERE status = 'draft');
  RAISE NOTICE '  - Sent: %', (SELECT COUNT(*) FROM invoices WHERE status = 'sent');
  RAISE NOTICE '  - Paid: %', (SELECT COUNT(*) FROM invoices WHERE status = 'paid');
  RAISE NOTICE '  - Overdue: %', (SELECT COUNT(*) FROM invoices WHERE status = 'overdue');
  RAISE NOTICE '  - Unpaid Deposits: %', (SELECT COUNT(*) FROM invoices WHERE deposit_required = true AND deposit_paid = false);
  RAISE NOTICE '';
  RAISE NOTICE 'Invoice Events: %', (SELECT COUNT(*) FROM invoice_events);
  RAISE NOTICE '';
  RAISE NOTICE 'File Assets: %', (SELECT COUNT(*) FROM file_assets);
  RAISE NOTICE '  - Proofs: %', (SELECT COUNT(*) FROM file_assets WHERE file_type = 'proof');
  RAISE NOTICE '  - Pending Approval: %', (SELECT COUNT(*) FROM file_assets WHERE approval_status = 'pending');
  RAISE NOTICE '  - Approved: %', (SELECT COUNT(*) FROM file_assets WHERE approval_status = 'approved');
  RAISE NOTICE '  - Rejected: %', (SELECT COUNT(*) FROM file_assets WHERE approval_status = 'rejected');
  RAISE NOTICE '';
  RAISE NOTICE 'Shipments: %', (SELECT COUNT(*) FROM shipments);
  RAISE NOTICE '  - Pending: %', (SELECT COUNT(*) FROM shipments WHERE status = 'pending');
  RAISE NOTICE '  - In Transit: %', (SELECT COUNT(*) FROM shipments WHERE status = 'in_transit');
  RAISE NOTICE '  - Delivered: %', (SELECT COUNT(*) FROM shipments WHERE status = 'delivered');
  RAISE NOTICE '  - Missing Tracking: %', (SELECT COUNT(*) FROM shipments WHERE tracking_number IS NULL AND status != 'pending');
  RAISE NOTICE '';
  RAISE NOTICE '=============================================================================';
  RAISE NOTICE 'ACTION QUEUE ITEMS';
  RAISE NOTICE '=============================================================================';
  RAISE NOTICE 'Action items requiring attention: %', (SELECT COUNT(*) FROM internal_action_queue);
  RAISE NOTICE '  - Priority 1 (Critical): %', (SELECT COUNT(*) FROM internal_action_queue WHERE priority = 1);
  RAISE NOTICE '  - Priority 2 (Important): %', (SELECT COUNT(*) FROM internal_action_queue WHERE priority = 2);
  RAISE NOTICE '';
  RAISE NOTICE 'By type:';
  RAISE NOTICE '  - Unpaid Deposits: %', (SELECT COUNT(*) FROM internal_action_queue WHERE action_type = 'deposit_unpaid');
  RAISE NOTICE '  - Due Soon: %', (SELECT COUNT(*) FROM internal_action_queue WHERE action_type = 'invoice_due_soon');
  RAISE NOTICE '  - Overdue: %', (SELECT COUNT(*) FROM internal_action_queue WHERE action_type = 'invoice_overdue');
  RAISE NOTICE '  - Pending Proofs: %', (SELECT COUNT(*) FROM internal_action_queue WHERE action_type = 'proof_pending');
  RAISE NOTICE '  - Missing Tracking: %', (SELECT COUNT(*) FROM internal_action_queue WHERE action_type = 'shipment_no_tracking');
  RAISE NOTICE '  - ETA Risks: %', (SELECT COUNT(*) FROM internal_action_queue WHERE action_type IN ('shipment_eta_risk', 'shipment_overdue'));
  RAISE NOTICE '';
  RAISE NOTICE '=============================================================================';
  RAISE NOTICE 'Seed data loaded successfully!';
  RAISE NOTICE '=============================================================================';
END $$;
