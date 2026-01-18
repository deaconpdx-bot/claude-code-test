/**
 * Supabase Database Type Definitions
 * Auto-generated type definitions for the Stone Forest App database schema
 *
 * This file contains TypeScript interfaces for all database tables and their relationships.
 * Use these types when querying and manipulating data through the Supabase client.
 */

// =============================================================================
// ENUM TYPES (PostgreSQL Enums)
// =============================================================================

export type InvoiceStatus = 'draft' | 'sent' | 'paid' | 'overdue' | 'cancelled';

export type InvoiceEventType =
  | 'created'
  | 'sent'
  | 'viewed'
  | 'payment_received'
  | 'payment_partial'
  | 'deposit_received'
  | 'reminder_7day'
  | 'reminder_due'
  | 'reminder_overdue'
  | 'marked_overdue'
  | 'cancelled';

export type FileType = 'proof' | 'artwork' | 'reference' | 'attachment';

export type ApprovalStatus = 'pending' | 'approved' | 'rejected' | 'revision' | 'final';

export type ShipmentStatus =
  | 'pending'
  | 'preparing'
  | 'shipped'
  | 'in_transit'
  | 'out_for_delivery'
  | 'delivered'
  | 'failed'
  | 'cancelled'
  | 'returned';

export type ShippingCarrier = 'usps' | 'ups' | 'fedex' | 'dhl' | 'other' | 'hand_delivery';

export type UserRole = 'admin' | 'staff' | 'customer';

export type OrganizationType = 'internal' | 'customer';

// =============================================================================
// ORGANIZATIONS TABLE
// =============================================================================

export interface Organization {
  id: string;
  name: string;
  type: OrganizationType;
  contact_email: string | null;
  contact_phone: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateOrganizationInput {
  name: string;
  type: OrganizationType;
  contact_email?: string;
  contact_phone?: string;
}

export interface UpdateOrganizationInput {
  name?: string;
  type?: OrganizationType;
  contact_email?: string | null;
  contact_phone?: string | null;
}

// =============================================================================
// USERS TABLE
// =============================================================================

export interface User {
  id: string;
  organization_id: string;
  email: string;
  name: string;
  role: UserRole;
  auth_user_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface UserWithOrganization extends User {
  organizations?: Organization;
}

export interface CreateUserInput {
  organization_id: string;
  email: string;
  name: string;
  role: UserRole;
  auth_user_id?: string;
}

export interface UpdateUserInput {
  email?: string;
  name?: string;
  role?: UserRole;
  auth_user_id?: string;
}

// =============================================================================
// PROJECTS TABLE
// =============================================================================

export interface Project {
  id: string;
  organization_id: string;
  name: string;
  description: string | null;
  status: 'active' | 'on_hold' | 'completed' | 'cancelled';
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface ProjectWithRelations extends Project {
  organizations?: Organization;
  created_by_user?: User;
}

export interface CreateProjectInput {
  organization_id: string;
  name: string;
  description?: string;
  created_by: string;
}

export interface UpdateProjectInput {
  name?: string;
  description?: string | null;
  status?: 'active' | 'on_hold' | 'completed' | 'cancelled';
}

// =============================================================================
// INVOICES TABLE
// =============================================================================

export interface Invoice {
  id: string;
  project_id: string;
  organization_id: string;
  invoice_number: string;
  issue_date: string;
  due_date: string;
  amount_subtotal: number;
  amount_tax: number;
  amount_total: number;
  amount_paid: number;
  balance_due: number;
  deposit_required: boolean;
  deposit_amount: number | null;
  deposit_paid: boolean;
  deposit_paid_at: string | null;
  status: InvoiceStatus;
  notes: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface InvoiceWithRelations extends Invoice {
  projects?: Project;
  organizations?: Organization;
  created_by_user?: User;
}

export interface CreateInvoiceInput {
  project_id: string;
  organization_id: string;
  invoice_number: string;
  issue_date: string;
  due_date: string;
  amount_subtotal: number;
  amount_tax?: number;
  amount_total: number;
  deposit_required?: boolean;
  deposit_amount?: number;
  created_by: string;
  notes?: string;
}

export interface UpdateInvoiceInput {
  amount_subtotal?: number;
  amount_tax?: number;
  amount_total?: number;
  amount_paid?: number;
  deposit_paid?: boolean;
  deposit_paid_at?: string;
  status?: InvoiceStatus;
  notes?: string | null;
}

// =============================================================================
// INVOICE EVENTS TABLE
// =============================================================================

export interface InvoiceEvent {
  id: string;
  invoice_id: string;
  event_type: InvoiceEventType;
  event_data: Record<string, any> | null;
  triggered_by: string | null;
  triggered_by_system: string | null;
  created_at: string;
}

export interface InvoiceEventWithRelations extends InvoiceEvent {
  invoices?: Invoice;
  triggered_by_user?: User;
}

export interface CreateInvoiceEventInput {
  invoice_id: string;
  event_type: InvoiceEventType;
  event_data?: Record<string, any>;
  triggered_by?: string;
  triggered_by_system?: string;
}

// =============================================================================
// FILE ASSETS TABLE
// =============================================================================

export interface FileAsset {
  id: string;
  project_id: string;
  organization_id: string;
  file_name: string;
  file_size_bytes: number;
  file_type: FileType;
  mime_type: string;
  storage_bucket: string;
  storage_path: string;
  version_number: number;
  is_current_version: boolean;
  parent_file_id: string | null;
  approval_status: ApprovalStatus | null;
  approved_by: string | null;
  approved_at: string | null;
  rejection_reason: string | null;
  uploaded_by: string;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface FileAssetWithRelations extends FileAsset {
  projects?: Project;
  organizations?: Organization;
  uploaded_by_user?: User;
  approved_by_user?: User;
  parent_file?: FileAsset;
}

export interface CreateFileAssetInput {
  project_id: string;
  organization_id: string;
  file_name: string;
  file_size_bytes: number;
  file_type: FileType;
  mime_type: string;
  storage_path: string;
  storage_bucket?: string;
  version_number?: number;
  parent_file_id?: string;
  uploaded_by: string;
  notes?: string;
}

export interface UpdateFileAssetInput {
  approval_status?: ApprovalStatus | null;
  approved_by?: string | null;
  approved_at?: string | null;
  rejection_reason?: string | null;
  notes?: string | null;
}

// =============================================================================
// APPROVAL EVENTS TABLE
// =============================================================================

export interface ApprovalEvent {
  id: string;
  file_asset_id: string;
  event_type: string;
  event_data: Record<string, any> | null;
  triggered_by: string | null;
  triggered_by_system: string | null;
  notification_sent: boolean;
  notification_sent_at: string | null;
  created_at: string;
}

export interface ApprovalEventWithRelations extends ApprovalEvent {
  file_assets?: FileAsset;
  triggered_by_user?: User;
}

export interface CreateApprovalEventInput {
  file_asset_id: string;
  event_type: string;
  event_data?: Record<string, any>;
  triggered_by?: string;
  triggered_by_system?: string;
}

export interface UpdateApprovalEventInput {
  notification_sent?: boolean;
  notification_sent_at?: string | null;
}

// =============================================================================
// SHIPMENTS TABLE
// =============================================================================

export interface Address {
  street?: string;
  city?: string;
  state?: string;
  zip?: string;
  country?: string;
}

export interface Shipment {
  id: string;
  project_id: string;
  organization_id: string;
  shipment_number: string;
  carrier: ShippingCarrier;
  tracking_number: string | null;
  tracking_url: string | null;
  status: ShipmentStatus;
  status_updated_at: string | null;
  expected_ship_date: string | null;
  actual_ship_date: string | null;
  expected_delivery_date: string | null;
  actual_delivery_date: string | null;
  ship_from_address: Address | null;
  ship_to_address: Address;
  package_count: number;
  weight_lbs: number | null;
  dimensions_inches: string | null;
  shipping_cost_cents: number | null;
  insurance_cost_cents: number;
  notes: string | null;
  internal_notes: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface ShipmentWithRelations extends Shipment {
  projects?: Project;
  organizations?: Organization;
  created_by_user?: User;
}

export interface CreateShipmentInput {
  project_id: string;
  organization_id: string;
  shipment_number: string;
  carrier: ShippingCarrier;
  tracking_number?: string;
  tracking_url?: string;
  ship_to_address: Address;
  ship_from_address?: Address;
  package_count?: number;
  weight_lbs?: number;
  dimensions_inches?: string;
  shipping_cost_cents?: number;
  insurance_cost_cents?: number;
  created_by: string;
  notes?: string;
  internal_notes?: string;
}

export interface UpdateShipmentInput {
  status?: ShipmentStatus;
  status_updated_at?: string;
  tracking_number?: string;
  tracking_url?: string;
  actual_ship_date?: string | null;
  actual_delivery_date?: string | null;
  notes?: string | null;
  internal_notes?: string | null;
}

// =============================================================================
// SHIPMENT EVENTS TABLE
// =============================================================================

export interface ShipmentEvent {
  id: string;
  shipment_id: string;
  event_type: string;
  event_data: Record<string, any> | null;
  old_status: ShipmentStatus | null;
  new_status: ShipmentStatus | null;
  location: string | null;
  location_coordinates: { x: number; y: number } | null;
  triggered_by: string | null;
  triggered_by_system: string | null;
  notification_sent: boolean;
  notification_sent_at: string | null;
  created_at: string;
}

export interface ShipmentEventWithRelations extends ShipmentEvent {
  shipments?: Shipment;
  triggered_by_user?: User;
}

export interface CreateShipmentEventInput {
  shipment_id: string;
  event_type: string;
  event_data?: Record<string, any>;
  old_status?: ShipmentStatus;
  new_status?: ShipmentStatus;
  location?: string;
  triggered_by?: string;
  triggered_by_system?: string;
}

export interface UpdateShipmentEventInput {
  notification_sent?: boolean;
  notification_sent_at?: string | null;
}

// =============================================================================
// DATABASE TYPE (for RPC and utility functions)
// =============================================================================

export type Database = {
  public: {
    Tables: {
      organizations: {
        Row: Organization;
        Insert: CreateOrganizationInput;
        Update: UpdateOrganizationInput;
      };
      users: {
        Row: User;
        Insert: CreateUserInput;
        Update: UpdateUserInput;
      };
      projects: {
        Row: Project;
        Insert: CreateProjectInput;
        Update: UpdateProjectInput;
      };
      invoices: {
        Row: Invoice;
        Insert: CreateInvoiceInput;
        Update: UpdateInvoiceInput;
      };
      invoice_events: {
        Row: InvoiceEvent;
        Insert: CreateInvoiceEventInput;
        Update: never;
      };
      file_assets: {
        Row: FileAsset;
        Insert: CreateFileAssetInput;
        Update: UpdateFileAssetInput;
      };
      approval_events: {
        Row: ApprovalEvent;
        Insert: CreateApprovalEventInput;
        Update: UpdateApprovalEventInput;
      };
      shipments: {
        Row: Shipment;
        Insert: CreateShipmentInput;
        Update: UpdateShipmentInput;
      };
      shipment_events: {
        Row: ShipmentEvent;
        Insert: CreateShipmentEventInput;
        Update: UpdateShipmentEventInput;
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: {
      invoice_status: InvoiceStatus;
      invoice_event_type: InvoiceEventType;
      file_type: FileType;
      approval_status: ApprovalStatus;
      shipment_status: ShipmentStatus;
      shipping_carrier: ShippingCarrier;
    };
  };
};
