import {
  Building2,
  CircleHelp,
  DoorOpen,
  FileText,
  Gauge,
  House,
  Landmark,
  Package,
  Phone,
  Settings,
  ShieldCheck,
  Umbrella,
  Users,
  WashingMachine,
  Wrench,
  Zap,
  type LucideIcon,
} from 'lucide-react';

export interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  description?: string;
}

export interface NavGroup {
  label?: string;
  items: NavItem[];
}

export const NAV_GROUPS: NavGroup[] = [
  {
    items: [
      { to: '/', label: 'Home', icon: House },
      { to: '/properties', label: 'Properties', icon: Building2, description: 'Your homes and their details' },
      { to: '/rooms', label: 'Rooms', icon: DoorOpen, description: 'What is where' },
    ],
  },
  {
    label: 'Belongings',
    items: [
      { to: '/appliances', label: 'Appliances', icon: WashingMachine, description: 'Models, receipts, manuals' },
      { to: '/inventory', label: 'Inventory', icon: Package, description: 'Possessions and their value' },
      { to: '/warranties', label: 'Warranties', icon: ShieldCheck, description: 'What is still covered' },
      { to: '/documents', label: 'Documents', icon: FileText, description: 'Receipts, manuals, certificates' },
    ],
  },
  {
    label: 'Upkeep',
    items: [
      { to: '/maintenance', label: 'Maintenance', icon: Wrench, description: 'Tasks and reminders' },
      { to: '/meter-readings', label: 'Meter readings', icon: Gauge, description: 'Electricity, gas and water' },
    ],
  },
  {
    label: 'Bills & cover',
    items: [
      { to: '/utilities', label: 'Utilities', icon: Zap, description: 'Energy, water, broadband' },
      { to: '/council-tax', label: 'Council tax', icon: Landmark, description: 'Account and payments' },
      { to: '/insurance', label: 'Insurance', icon: Umbrella, description: 'Policies and renewals' },
    ],
  },
  {
    label: 'People',
    items: [
      { to: '/household', label: 'Household', icon: Users, description: 'Who lives here' },
      { to: '/emergency', label: 'Emergency', icon: Phone, description: 'Important numbers' },
    ],
  },
];

export const SETTINGS_ITEM: NavItem = {
  to: '/settings',
  label: 'Settings',
  icon: Settings,
  description: 'Account and preferences',
};

export const HELP_ITEM: NavItem = {
  to: '/help',
  label: 'Help & tutorials',
  icon: CircleHelp,
  description: 'Step-by-step guides and the tour',
};

/** Shown on the mobile "More" page — everything not in the bottom bar. */
export const MORE_ITEMS: NavItem[] = [
  ...NAV_GROUPS.flatMap((g) => g.items).filter((i) => !['/', '/properties', '/maintenance', '/documents'].includes(i.to)),
  HELP_ITEM,
  SETTINGS_ITEM,
];
