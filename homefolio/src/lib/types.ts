export interface Timestamps {
  created_at: string;
  updated_at: string;
}

export interface Owned extends Timestamps {
  id: string;
  user_id: string;
  property_id: string;
}

export interface Profile extends Timestamps {
  id: string;
  full_name: string | null;
  theme: ThemePreference;
  reminder_window_days: number;
  remind_maintenance: boolean;
  remind_warranties: boolean;
  remind_insurance: boolean;
  remind_contracts: boolean;
  plan: 'free' | 'plus';
  plan_expires_at: string | null;
  plan_source: string | null;
  is_admin: boolean;
  /** When the welcome tour was finished or skipped; null shows it again. */
  tour_completed_at: string | null;
}

export type ThemePreference = 'system' | 'light' | 'dark';

export interface Property extends Timestamps {
  id: string;
  user_id: string;
  name: string;
  address_line1: string | null;
  address_line2: string | null;
  town: string | null;
  postcode: string | null;
  property_type: string;
  ownership_status: string;
  bedrooms: number | null;
  bathrooms: number | null;
  year_built: number | null;
  move_in_date: string | null;
  notes: string | null;
  is_sample: boolean;
}

export interface Room extends Owned {
  name: string;
  room_type: string | null;
  notes: string | null;
}

interface ItemBase extends Owned {
  room_id: string | null;
  name: string;
  category: string | null;
  brand: string | null;
  model: string | null;
  serial_number: string | null;
  purchase_date: string | null;
  purchase_price: number | null;
  retailer: string | null;
  notes: string | null;
}

export interface Appliance extends ItemBase {
  condition: string | null;
}

export interface InventoryItem extends ItemBase {
  current_value: number | null;
}

export interface Warranty extends Owned {
  appliance_id: string | null;
  inventory_item_id: string | null;
  provider: string | null;
  start_date: string | null;
  expiry_date: string | null;
  notes: string | null;
}

export type Recurrence = 'none' | 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'biannual' | 'yearly' | 'custom';
export type RecurrenceUnit = 'day' | 'week' | 'month' | 'year';

export interface MaintenanceTask extends Owned {
  room_id: string | null;
  appliance_id: string | null;
  series_id: string | null;
  title: string;
  description: string | null;
  category: string | null;
  due_date: string;
  recurrence: Recurrence;
  recurrence_interval: number | null;
  recurrence_unit: RecurrenceUnit | null;
  completed_at: string | null;
  notes: string | null;
}

export interface Utility extends Owned {
  utility_type: string;
  label: string | null;
  provider: string | null;
  account_number: string | null;
  tariff: string | null;
  contract_start: string | null;
  contract_end: string | null;
  monthly_cost: number | null;
  contact_phone: string | null;
  contact_email: string | null;
  website: string | null;
  notes: string | null;
}

export interface CouncilTax extends Owned {
  council: string | null;
  account_number: string | null;
  band: string | null;
  monthly_amount: number | null;
  payment_day: number | null;
  notes: string | null;
}

export interface InsurancePolicy extends Owned {
  policy_type: string;
  provider: string | null;
  policy_number: string | null;
  start_date: string | null;
  renewal_date: string | null;
  premium: number | null;
  premium_frequency: 'monthly' | 'yearly';
  contact_phone: string | null;
  emergency_phone: string | null;
  contact_email: string | null;
  notes: string | null;
}

export type MeterType = 'electricity' | 'gas' | 'water';

export interface MeterReading extends Owned {
  meter_type: MeterType;
  reading: number;
  reading_date: string;
  notes: string | null;
}

export interface HouseholdMember extends Owned {
  linked_user_id: string | null;
  name: string;
  relationship: string | null;
  email: string | null;
  phone: string | null;
  notes: string | null;
  is_emergency_contact: boolean;
}

export interface EmergencyContact extends Owned {
  contact_type: string;
  name: string;
  phone: string | null;
  alt_phone: string | null;
  email: string | null;
  notes: string | null;
}

/** The item a document or photo can be attached to. */
export type LinkKey =
  | 'room_id'
  | 'appliance_id'
  | 'inventory_item_id'
  | 'maintenance_task_id'
  | 'insurance_policy_id'
  | 'utility_id'
  | 'council_tax_id'
  | 'meter_reading_id';

export interface HomeDocument extends Owned {
  room_id: string | null;
  appliance_id: string | null;
  inventory_item_id: string | null;
  maintenance_task_id: string | null;
  insurance_policy_id: string | null;
  utility_id: string | null;
  council_tax_id: string | null;
  name: string;
  category: string;
  file_path: string | null;
  file_name: string | null;
  mime_type: string | null;
  size_bytes: number | null;
  notes: string | null;
  extracted_text: string | null;
}

export interface Photo extends Owned {
  room_id: string | null;
  appliance_id: string | null;
  inventory_item_id: string | null;
  maintenance_task_id: string | null;
  meter_reading_id: string | null;
  file_path: string;
  caption: string | null;
  size_bytes: number | null;
}

export type CustomFieldEntity = 'property' | 'room' | 'appliance' | 'inventory';

export interface CustomField extends Owned {
  entity_type: CustomFieldEntity;
  entity_id: string;
  label: string;
  value: string | null;
  sort_order: number;
}

export type CategoryKind = 'room' | 'appliance' | 'inventory' | 'document' | 'utility' | 'maintenance' | 'contact';

export interface CustomCategory {
  id: string;
  user_id: string;
  kind: CategoryKind;
  name: string;
  created_at: string;
}

export interface PropertySummary {
  rooms: number;
  appliances: number;
  inventory: number;
  documents: number;
  open_tasks: number;
  overdue_tasks: number;
  active_warranties: number;
}

export type ReminderKind = 'maintenance' | 'warranty' | 'insurance' | 'contract';

export interface Reminder {
  kind: ReminderKind;
  item_id: string;
  title: string;
  detail: string | null;
  due_date: string;
}

export type SearchKind =
  | 'appliance'
  | 'inventory'
  | 'document'
  | 'maintenance'
  | 'warranty'
  | 'inventory_warranty'
  | 'room'
  | 'utility'
  | 'insurance'
  | 'contact'
  | 'household';

export interface SearchResult {
  kind: SearchKind;
  item_id: string;
  title: string;
  subtitle: string | null;
  property_id: string;
}

export type AdPlacement = 'dashboard' | 'maintenance' | 'appliances' | 'utilities' | 'insurance';

export interface AdCampaign {
  id: string;
  advertiser: string;
  placement: AdPlacement;
  headline: string;
  body: string | null;
  cta_label: string;
  url: string;
  logo_url: string | null;
  starts_on: string;
  ends_on: string;
  weight: number;
  active: boolean;
  price_per_month: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface StorageStatus {
  used: number;
  limit: number;
  plus: boolean;
}
