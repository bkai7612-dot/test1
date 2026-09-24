import type { CategoryKind, Recurrence } from './types';

export interface Option {
  value: string;
  label: string;
}

const same = (values: string[]): Option[] => values.map((v) => ({ value: v, label: v }));

export const PROPERTY_TYPES: Option[] = [
  { value: 'house', label: 'House' },
  { value: 'flat', label: 'Flat / Apartment' },
  { value: 'bungalow', label: 'Bungalow' },
  { value: 'maisonette', label: 'Maisonette' },
  { value: 'other', label: 'Other' },
];

export const OWNERSHIP_STATUSES: Option[] = [
  { value: 'owner', label: 'Owner' },
  { value: 'renter', label: 'Renter' },
  { value: 'other', label: 'Other' },
];

/** Built-in categories per kind. Users can add their own on top (custom_categories). */
export const DEFAULT_CATEGORIES: Record<CategoryKind, string[]> = {
  room: ['Living Room', 'Kitchen', 'Bedroom', 'Bathroom', 'Hallway', 'Garden', 'Garage', 'Other'],
  appliance: [
    'Washing machine',
    'Dishwasher',
    'Fridge',
    'Freezer',
    'Oven',
    'Microwave',
    'Television',
    'Computer',
    'Boiler',
    'Heating',
    'Air conditioning',
    'Vacuum cleaner',
    'Other',
  ],
  inventory: ['Electronics', 'Furniture', 'Kitchen', 'Clothing', 'Jewellery', 'Tools', 'Sports', 'Other'],
  document: ['Receipts', 'Manuals', 'Insurance', 'Warranties', 'Property', 'Utilities', 'Maintenance', 'Other'],
  utility: ['Electricity', 'Gas', 'Water', 'Broadband'],
  maintenance: ['Heating', 'Safety', 'Cleaning', 'Exterior', 'Garden', 'Plumbing', 'Electrical', 'Appliances', 'Other'],
  contact: [
    'Gas emergency',
    'Electricity emergency',
    'Water emergency',
    'Landlord / Property manager',
    'Building manager',
    'Insurance emergency',
    'Plumber',
    'Electrician',
    'Doctor',
    'Neighbour',
    'Other',
  ],
};

export const CONDITIONS = same(['Excellent', 'Good', 'Fair', 'Poor', 'Not working']);

export const RECURRENCE_OPTIONS: { value: Recurrence; label: string }[] = [
  { value: 'none', label: 'Does not repeat' },
  { value: 'daily', label: 'Daily' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
  { value: 'quarterly', label: 'Every 3 months' },
  { value: 'biannual', label: 'Every 6 months' },
  { value: 'yearly', label: 'Yearly' },
  { value: 'custom', label: 'Custom…' },
];

export const RECURRENCE_UNITS: Option[] = [
  { value: 'day', label: 'Days' },
  { value: 'week', label: 'Weeks' },
  { value: 'month', label: 'Months' },
  { value: 'year', label: 'Years' },
];

export const INSURANCE_TYPES: Option[] = [
  { value: 'home', label: 'Home (buildings & contents)' },
  { value: 'contents', label: 'Contents' },
  { value: 'buildings', label: 'Buildings' },
  { value: 'landlord', label: 'Landlord' },
  { value: 'appliance', label: 'Appliance cover' },
  { value: 'boiler', label: 'Boiler cover' },
  { value: 'other', label: 'Other' },
];

export const METER_TYPES: { value: 'electricity' | 'gas' | 'water'; label: string; unit: string }[] = [
  { value: 'electricity', label: 'Electricity', unit: 'kWh' },
  { value: 'gas', label: 'Gas', unit: 'm³' },
  { value: 'water', label: 'Water', unit: 'm³' },
];

export const RELATIONSHIPS = same(['Partner', 'Spouse', 'Child', 'Parent', 'Sibling', 'Housemate', 'Lodger', 'Carer', 'Other']);

/** Upload limits mirror the storage bucket configuration in the database. */
export const MAX_UPLOAD_BYTES = 20 * 1024 * 1024;
export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif'];
export const DOCUMENT_TYPES = [
  ...IMAGE_TYPES,
  'application/pdf',
  'text/plain',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
];
export const DOCUMENT_ACCEPT = '.pdf,.txt,.doc,.docx,image/*';

export const PAGE_SIZE = 24;
