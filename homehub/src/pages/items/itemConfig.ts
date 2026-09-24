import { Package, WashingMachine, type LucideIcon } from 'lucide-react';
import type { FieldDef } from '@/components/forms/EntityForm';
import type { Table } from '@/lib/api';
import { APPLIANCE_FIELDS, INVENTORY_FIELDS } from '@/lib/fields';
import type { CategoryKind, CustomFieldEntity, LinkKey } from '@/lib/types';

export type ItemKind = 'appliance' | 'inventory';

export interface ItemConfig {
  table: Table;
  path: string;
  singular: string;
  plural: string;
  icon: LucideIcon;
  fields: FieldDef[];
  linkKey: LinkKey;
  warrantyKey: 'appliance_id' | 'inventory_item_id';
  categoryKind: CategoryKind;
  customEntity: CustomFieldEntity;
  emptyText: string;
}

/** Appliances and inventory share list/detail pages; this is what differs between them. */
export const ITEM_CONFIG: Record<ItemKind, ItemConfig> = {
  appliance: {
    table: 'appliances',
    path: '/appliances',
    singular: 'appliance',
    plural: 'Appliances',
    icon: WashingMachine,
    fields: APPLIANCE_FIELDS,
    linkKey: 'appliance_id',
    warrantyKey: 'appliance_id',
    categoryKind: 'appliance',
    customEntity: 'appliance',
    emptyText: "Keep track of your home's appliances, warranties, receipts and manuals.",
  },
  inventory: {
    table: 'inventory_items',
    path: '/inventory',
    singular: 'item',
    plural: 'Inventory',
    icon: Package,
    fields: INVENTORY_FIELDS,
    linkKey: 'inventory_item_id',
    warrantyKey: 'inventory_item_id',
    categoryKind: 'inventory',
    customEntity: 'inventory',
    emptyText: 'Record your possessions and their value — handy for insurance claims.',
  },
};
