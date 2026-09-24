import type { FieldDef } from '@/components/forms/EntityForm';
import {
  CONDITIONS,
  INSURANCE_TYPES,
  METER_TYPES,
  OWNERSHIP_STATUSES,
  PROPERTY_TYPES,
  RECURRENCE_OPTIONS,
  RECURRENCE_UNITS,
  RELATIONSHIPS,
} from './constants';

export const PROPERTY_FIELDS: FieldDef[] = [
  { name: 'name', label: 'Property name', type: 'text', required: true, placeholder: 'e.g. My Home', maxLength: 120 },
  { name: 'address_line1', label: 'Address', type: 'text', placeholder: 'e.g. 24 Example Street' },
  { name: 'address_line2', label: 'Address line 2', type: 'text' },
  { name: 'town', label: 'Town / city', type: 'text', half: true },
  { name: 'postcode', label: 'Postcode', type: 'text', half: true, maxLength: 12 },
  { name: 'property_type', label: 'Property type', type: 'select', options: PROPERTY_TYPES, required: true, half: true },
  { name: 'ownership_status', label: 'I am the…', type: 'select', options: OWNERSHIP_STATUSES, required: true, half: true },
  { name: 'bedrooms', label: 'Bedrooms', type: 'number', min: 0, max: 100, step: '1', half: true },
  { name: 'bathrooms', label: 'Bathrooms', type: 'number', min: 0, max: 100, step: '1', half: true },
  {
    name: 'year_built',
    label: 'Year built',
    type: 'number',
    min: 1000,
    max: 2200,
    step: '1',
    half: true,
    placeholder: 'e.g. 1998',
  },
  { name: 'move_in_date', label: 'Purchase / move-in date', type: 'date', half: true },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];

export const ROOM_FIELDS: FieldDef[] = [
  { name: 'room_type', label: 'Type of room', type: 'category', categoryKind: 'room', half: true },
  {
    name: 'name',
    label: 'Room name',
    type: 'text',
    placeholder: 'e.g. Main bedroom',
    hint: 'Leave blank to use the type.',
    half: true,
    maxLength: 120,
  },
  { name: 'notes', label: 'Notes', type: 'textarea', placeholder: 'e.g. Paint colour, where the stopcock is' },
];

const ITEM_COMMON: FieldDef[] = [
  { name: 'brand', label: 'Brand', type: 'text', half: true },
  { name: 'model', label: 'Model', type: 'text', half: true },
  { name: 'serial_number', label: 'Serial number', type: 'text', half: true },
  { name: 'room_id', label: 'Room', type: 'room', half: true },
  { name: 'purchase_date', label: 'Purchase date', type: 'date', half: true, section: 'Purchase' },
  { name: 'purchase_price', label: 'Purchase price', type: 'money', half: true },
  { name: 'retailer', label: 'Retailer', type: 'text', half: true, placeholder: 'Where you bought it' },
];

export const APPLIANCE_FIELDS: FieldDef[] = [
  { name: 'name', label: 'Name', type: 'text', required: true, placeholder: 'e.g. Samsung Washing Machine', maxLength: 200 },
  { name: 'category', label: 'Category', type: 'category', categoryKind: 'appliance', half: true },
  { name: 'condition', label: 'Condition', type: 'select', options: CONDITIONS, half: true },
  ...ITEM_COMMON,
  { name: 'notes', label: 'Notes', type: 'textarea', section: 'Other' },
];

export const INVENTORY_FIELDS: FieldDef[] = [
  { name: 'name', label: 'Item name', type: 'text', required: true, placeholder: 'e.g. Sony Television', maxLength: 200 },
  { name: 'category', label: 'Category', type: 'category', categoryKind: 'inventory', half: true },
  { name: 'current_value', label: 'Current estimated value', type: 'money', half: true },
  ...ITEM_COMMON,
  { name: 'notes', label: 'Notes', type: 'textarea', section: 'Other' },
];

/** Warranty fields are prefixed so they can live in the same form as the item. */
export const WARRANTY_FIELDS: FieldDef[] = [
  { name: 'w_start_date', label: 'Warranty start', type: 'date', half: true, section: 'Warranty' },
  { name: 'w_expiry_date', label: 'Warranty expiry', type: 'date', half: true },
  { name: 'w_provider', label: 'Warranty provider', type: 'text', placeholder: 'e.g. Manufacturer or retailer' },
];

export const WARRANTY_ONLY_FIELDS: FieldDef[] = [
  { name: 'start_date', label: 'Warranty start', type: 'date', half: true },
  { name: 'expiry_date', label: 'Warranty expiry', type: 'date', half: true, required: true },
  { name: 'provider', label: 'Warranty provider', type: 'text', placeholder: 'e.g. Manufacturer or retailer' },
  { name: 'notes', label: 'Notes', type: 'textarea', placeholder: 'e.g. What is covered, how to claim' },
];

export const MAINTENANCE_FIELDS: FieldDef[] = [
  { name: 'title', label: 'Task', type: 'text', required: true, placeholder: 'e.g. Boiler service', maxLength: 200 },
  { name: 'due_date', label: 'Due date', type: 'date', required: true, half: true },
  { name: 'category', label: 'Category', type: 'category', categoryKind: 'maintenance', half: true },
  { name: 'recurrence', label: 'Repeat', type: 'select', options: RECURRENCE_OPTIONS, required: true },
  {
    name: 'recurrence_interval',
    label: 'Every',
    type: 'number',
    min: 1,
    max: 999,
    step: '1',
    half: true,
    required: true,
    showIf: (v) => v.recurrence === 'custom',
  },
  {
    name: 'recurrence_unit',
    label: 'Unit',
    type: 'select',
    options: RECURRENCE_UNITS,
    half: true,
    required: true,
    showIf: (v) => v.recurrence === 'custom',
  },
  { name: 'room_id', label: 'Room', type: 'room', half: true },
  { name: 'description', label: 'Description', type: 'textarea', placeholder: 'What needs doing?' },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];

export const UTILITY_FIELDS: FieldDef[] = [
  { name: 'utility_type', label: 'Type', type: 'category', categoryKind: 'utility', required: true, half: true },
  { name: 'provider', label: 'Provider', type: 'text', half: true, placeholder: 'e.g. Octopus Energy' },
  { name: 'account_number', label: 'Account / reference number', type: 'text', half: true },
  { name: 'tariff', label: 'Tariff / package', type: 'text', half: true },
  { name: 'monthly_cost', label: 'Monthly cost', type: 'money', half: true },
  { name: 'contract_start', label: 'Contract start', type: 'date', half: true },
  { name: 'contract_end', label: 'Contract end', type: 'date', half: true },
  { name: 'contact_phone', label: 'Phone', type: 'tel', half: true, section: 'Contact' },
  { name: 'contact_email', label: 'Email', type: 'email', half: true },
  { name: 'website', label: 'Website', type: 'url', placeholder: 'https://' },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];

export const COUNCIL_TAX_FIELDS: FieldDef[] = [
  { name: 'council', label: 'Council', type: 'text', placeholder: 'e.g. Sampletown Borough Council' },
  { name: 'account_number', label: 'Account / reference number', type: 'text', half: true },
  { name: 'band', label: 'Band', type: 'text', half: true, maxLength: 3, placeholder: 'e.g. C' },
  { name: 'monthly_amount', label: 'Monthly amount', type: 'money', half: true },
  {
    name: 'payment_day',
    label: 'Payment day of month',
    type: 'number',
    min: 1,
    max: 31,
    step: '1',
    half: true,
    placeholder: 'e.g. 1',
  },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];

export const INSURANCE_FIELDS: FieldDef[] = [
  { name: 'policy_type', label: 'Type of cover', type: 'select', options: INSURANCE_TYPES, required: true, half: true },
  { name: 'provider', label: 'Provider', type: 'text', half: true },
  { name: 'policy_number', label: 'Policy number', type: 'text', half: true },
  { name: 'premium', label: 'Premium', type: 'money', half: true },
  {
    name: 'premium_frequency',
    label: 'Paid',
    type: 'select',
    required: true,
    half: true,
    options: [
      { value: 'yearly', label: 'Yearly' },
      { value: 'monthly', label: 'Monthly' },
    ],
  },
  { name: 'start_date', label: 'Start date', type: 'date', half: true },
  { name: 'renewal_date', label: 'Renewal date', type: 'date', half: true },
  { name: 'contact_phone', label: 'Customer services phone', type: 'tel', half: true, section: 'Contact' },
  { name: 'emergency_phone', label: 'Claims / emergency phone', type: 'tel', half: true },
  { name: 'contact_email', label: 'Email', type: 'email' },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];

export const METER_FIELDS: FieldDef[] = [
  { name: 'meter_type', label: 'Meter', type: 'select', required: true, options: METER_TYPES, half: true },
  { name: 'reading_date', label: 'Date', type: 'date', required: true, half: true },
  { name: 'reading', label: 'Reading', type: 'number', required: true, min: 0, placeholder: 'e.g. 21450' },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];

export const HOUSEHOLD_FIELDS: FieldDef[] = [
  { name: 'name', label: 'Name', type: 'text', required: true, half: true, maxLength: 120 },
  { name: 'relationship', label: 'Relationship', type: 'select', options: RELATIONSHIPS, half: true },
  { name: 'phone', label: 'Phone', type: 'tel', half: true },
  { name: 'email', label: 'Email', type: 'email', half: true },
  { name: 'is_emergency_contact', label: 'Emergency contact', type: 'toggle', hint: 'Show on the Emergency page.' },
  { name: 'notes', label: 'Notes', type: 'textarea', placeholder: 'e.g. Allergies, medication, key holder' },
];

export const EMERGENCY_FIELDS: FieldDef[] = [
  { name: 'contact_type', label: 'Type', type: 'category', categoryKind: 'contact', required: true, half: true },
  { name: 'name', label: 'Name', type: 'text', required: true, half: true, maxLength: 120 },
  { name: 'phone', label: 'Phone', type: 'tel', half: true },
  { name: 'alt_phone', label: 'Other phone', type: 'tel', half: true },
  { name: 'email', label: 'Email', type: 'email' },
  { name: 'notes', label: 'Notes', type: 'textarea' },
];
