import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { useToast } from '@/context/ToastContext';
import { useRooms } from '@/hooks/useData';
import { insertRow, updateRow } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { WARRANTY_FIELDS } from '@/lib/fields';
import { supabase } from '@/lib/supabase';
import type { Appliance, InventoryItem, Warranty } from '@/lib/types';
import { ITEM_CONFIG, type ItemKind } from './itemConfig';

type Item = Appliance | InventoryItem;

interface ItemFormModalProps {
  kind: ItemKind;
  open: boolean;
  onClose: () => void;
  propertyId: string;
  item?: Item | null;
  /** Only used when creating: warranty fields are part of the "add" form. */
  defaultRoomId?: string | null;
  onSaved: (item: Item) => void;
}

export function ItemFormModal({ kind, open, onClose, propertyId, item, defaultRoomId, onSaved }: ItemFormModalProps) {
  const cfg = ITEM_CONFIG[kind];
  const toast = useToast();
  const { data: rooms } = useRooms(propertyId);
  // Warranty is captured while adding; afterwards it's edited from the item's warranty card.
  const fields = item ? cfg.fields : [...cfg.fields.slice(0, -1), ...WARRANTY_FIELDS, cfg.fields[cfg.fields.length - 1]];

  return (
    <FormModal
      open={open}
      onClose={onClose}
      title={item ? `Edit ${cfg.singular}` : `Add ${cfg.singular === 'item' ? 'an inventory item' : 'an appliance'}`}
      fields={fields}
      rooms={rooms}
      initial={toFormValues(fields, item, { room_id: defaultRoomId ?? '' })}
      extraValidate={(v) =>
        v.w_start_date && v.w_expiry_date && v.w_expiry_date < v.w_start_date
          ? { w_expiry_date: 'Expiry must be after the start date.' }
          : {}
      }
      onSubmit={async (payload) => {
        const { w_start_date, w_expiry_date, w_provider, ...values } = payload;
        if (item) {
          const saved = await updateRow<Item>(cfg.table, item.id, values);
          toast.success('Changes saved');
          onSaved(saved);
        } else {
          const saved = await insertRow<Item>(cfg.table, { ...values, property_id: propertyId });
          if (w_start_date || w_expiry_date || w_provider) {
            unwrap(
              await supabase.from('warranties').insert({
                property_id: propertyId,
                [cfg.warrantyKey]: saved.id,
                start_date: w_start_date,
                expiry_date: w_expiry_date,
                provider: w_provider,
              }),
            );
          }
          toast.success(`${saved.name} added`);
          onSaved(saved);
        }
        onClose();
      }}
    />
  );
}

export async function saveWarranty(
  existing: Warranty | null,
  propertyId: string,
  key: 'appliance_id' | 'inventory_item_id',
  itemId: string,
  values: Record<string, unknown>,
): Promise<Warranty> {
  if (existing) return updateRow<Warranty>('warranties', existing.id, values);
  return insertRow<Warranty>('warranties', { ...values, property_id: propertyId, [key]: itemId });
}
