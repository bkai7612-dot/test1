import { Building2, Check, ChevronRight, Plus } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { FormModal, toFormValues, type FieldDef } from '@/components/forms/EntityForm';
import { Tag } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { PageHeader } from '@/components/ui/Layout';
import { useProperties } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { usePlan } from '@/hooks/usePlan';
import { insertRow, updateRow } from '@/lib/api';
import { PROPERTY_TYPES } from '@/lib/constants';
import { PROPERTY_FIELDS } from '@/lib/fields';
import { labelFor, propertyAddress } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { Property } from '@/lib/types';
import { cn } from '@/lib/cn';

const STARTER_ROOMS = ['Kitchen', 'Living Room', 'Bedroom', 'Bathroom', 'Hallway'];

const NEW_PROPERTY_FIELDS: FieldDef[] = [
  ...PROPERTY_FIELDS,
  {
    name: 'add_rooms',
    label: 'Add common rooms',
    type: 'toggle',
    hint: `Kitchen, living room, bedroom, bathroom and hallway. You can change these later.`,
  },
];

export function PropertyFormModal({
  open,
  onClose,
  property,
}: {
  open: boolean;
  onClose: () => void;
  property?: Property | null;
}) {
  const { reload, setActive } = useProperties();
  const toast = useToast();
  const fields = property ? PROPERTY_FIELDS : NEW_PROPERTY_FIELDS;

  return (
    <FormModal
      open={open}
      onClose={onClose}
      title={property ? 'Edit property' : 'Add a property'}
      fields={fields}
      initial={toFormValues(fields, property, { property_type: 'house', ownership_status: 'owner', add_rooms: true })}
      submitLabel={property ? 'Save' : 'Add property'}
      onSubmit={async (payload) => {
        const { add_rooms, ...values } = payload;
        if (property) {
          await updateRow('properties', property.id, values);
          toast.success('Property updated');
        } else {
          const created = await insertRow<Property>('properties', values);
          if (add_rooms) {
            await supabase
              .from('rooms')
              .insert(STARTER_ROOMS.map((name) => ({ property_id: created.id, name, room_type: name })));
          }
          setActive(created.id);
          toast.success(`${created.name} added`);
        }
        await reload();
        onClose();
      }}
    />
  );
}

export default function Properties() {
  const { properties, active, setActive, loading, error, reload } = useProperties();
  const editor = useEditor<Property>();
  const navigate = useNavigate();
  const { isPlus } = usePlan();
  // The free plan includes one property (the sample home doesn't count).
  const addProperty = () => {
    if (!isPlus && properties.some((p) => !p.is_sample)) navigate('/upgrade?reason=properties');
    else editor.openNew();
  };

  return (
    <>
      <PageHeader
        title="Properties"
        description="Each property keeps its own rooms, appliances, documents and reminders."
        actions={
          <Button icon={Plus} onClick={addProperty}>
            Add property
          </Button>
        }
      />
      {loading ? (
        <ListSkeleton rows={2} />
      ) : error && !properties.length ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !properties.length ? (
        <EmptyState
          icon={Building2}
          title="No properties yet"
          description="Add your home to start keeping everything about it in one place."
          action={
            <Button icon={Plus} onClick={addProperty}>
              Add property
            </Button>
          }
        />
      ) : (
        <ul className="grid grid-cols-1 gap-3 md:grid-cols-2">
          {properties.map((p) => {
            const isActive = p.id === active?.id;
            return (
              <li
                key={p.id}
                className={cn(
                  'bg-surface flex flex-col rounded-2xl border p-4 sm:p-5',
                  isActive ? 'border-brand-400 ring-brand-400 ring-1' : 'border-line',
                )}
              >
                <button
                  type="button"
                  onClick={() => navigate(`/properties/${p.id}`)}
                  className="flex items-start gap-3 text-left"
                >
                  <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-11 shrink-0 items-center justify-center rounded-xl">
                    <Building2 className="size-5" aria-hidden />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex flex-wrap items-center gap-2">
                      <span className="text-ink truncate font-semibold">{p.name}</span>
                      {p.is_sample && <Tag>Sample</Tag>}
                    </span>
                    <span className="text-muted mt-0.5 block text-sm">{propertyAddress(p) || 'No address added'}</span>
                    <span className="text-muted mt-0.5 block text-sm">{labelFor(PROPERTY_TYPES, p.property_type)}</span>
                  </span>
                  <ChevronRight className="text-muted mt-3 size-4 shrink-0" aria-hidden />
                </button>
                <div className="border-line mt-4 flex gap-2 border-t pt-3">
                  {isActive ? (
                    <span className="text-brand-fg inline-flex min-h-9 items-center gap-1.5 px-1 text-sm font-medium">
                      <Check className="size-4" aria-hidden /> Currently viewing
                    </span>
                  ) : (
                    <Button variant="secondary" size="sm" onClick={() => setActive(p.id)}>
                      Switch to this property
                    </Button>
                  )}
                  <Button variant="ghost" size="sm" className="ml-auto" onClick={() => editor.openEdit(p)}>
                    Edit
                  </Button>
                </div>
              </li>
            );
          })}
        </ul>
      )}
      <PropertyFormModal open={editor.isOpen} onClose={editor.close} property={editor.row} />
    </>
  );
}
