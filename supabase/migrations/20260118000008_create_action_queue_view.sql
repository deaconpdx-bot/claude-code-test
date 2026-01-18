-- Migration: Create Internal Action Queue View
-- Description: Creates a unified view of all actionable items for internal staff,
--              including unpaid deposits, overdue invoices, pending proofs, and shipment issues.
-- Sprint: 002A - Supabase Foundation

-- =============================================================================
-- INTERNAL ACTION QUEUE VIEW
-- =============================================================================

-- This view combines various action items that need staff attention
-- Priority levels: 1 (critical/urgent), 2 (important), 3 (routine)
CREATE OR REPLACE VIEW internal_action_queue AS

-- =============================================================================
-- 1. UNPAID DEPOSITS (Priority 1 - Critical)
-- =============================================================================
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

-- =============================================================================
-- 2. INVOICES DUE SOON (Priority 2 - Important)
-- =============================================================================
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

-- =============================================================================
-- 3. OVERDUE INVOICES (Priority 1 - Critical)
-- =============================================================================
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

-- =============================================================================
-- 4. PENDING PROOF APPROVALS (Priority 2 - Important)
-- =============================================================================
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

-- =============================================================================
-- 5. MISSING TRACKING NUMBERS (Priority 2 - Important)
-- =============================================================================
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

-- =============================================================================
-- 6. SHIPMENT ETA RISKS (Priority 1 - Critical if overdue, 2 if approaching)
-- =============================================================================
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
    -- Overdue deliveries
    s.expected_delivery_date < CURRENT_DATE
    OR
    -- Deliveries within next 2 days
    s.expected_delivery_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '2 days'
  )

-- =============================================================================
-- ORDERING
-- =============================================================================
ORDER BY
  priority ASC,
  due_date ASC NULLS LAST,
  created_date ASC;

-- Add helpful comment
COMMENT ON VIEW internal_action_queue IS
  'Unified action queue for internal staff showing all items requiring attention, ordered by priority';

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

-- Grant SELECT to authenticated users (RLS will filter by organization)
GRANT SELECT ON internal_action_queue TO authenticated;

COMMENT ON COLUMN internal_action_queue.action_type IS
  'Type of action: deposit_unpaid, invoice_due_soon, invoice_overdue, proof_pending, shipment_no_tracking, shipment_eta_risk, shipment_overdue';
COMMENT ON COLUMN internal_action_queue.priority IS
  'Priority level: 1 (critical/urgent), 2 (important), 3 (routine)';
COMMENT ON COLUMN internal_action_queue.record_id IS
  'UUID of the underlying record (invoice, proof, or shipment)';
COMMENT ON COLUMN internal_action_queue.identifier IS
  'Human-readable identifier (invoice number, version, tracking number, etc.)';
COMMENT ON COLUMN internal_action_queue.title IS
  'Short title describing the action item';
COMMENT ON COLUMN internal_action_queue.description IS
  'Detailed description with context and urgency information';
COMMENT ON COLUMN internal_action_queue.organization_id IS
  'Customer organization ID for filtering';
COMMENT ON COLUMN internal_action_queue.customer_name IS
  'Customer organization name for display';
COMMENT ON COLUMN internal_action_queue.project_id IS
  'Related project ID';
COMMENT ON COLUMN internal_action_queue.project_name IS
  'Related project name for display';
COMMENT ON COLUMN internal_action_queue.created_date IS
  'When the underlying record was created';
COMMENT ON COLUMN internal_action_queue.due_date IS
  'Due date or expected completion date (if applicable)';
COMMENT ON COLUMN internal_action_queue.days_open IS
  'Number of days since the item was created';
COMMENT ON COLUMN internal_action_queue.metadata IS
  'Additional context stored as JSONB for flexibility';
