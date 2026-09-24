import { ListPlus, Pencil, Plus, Trash2 } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { useToast } from '@/context/ToastContext';
import { useQuery } from '@/hooks/useQuery';
import { deleteRow, insertRow, updateRow } from '@/lib/api';
import { friendlyError, unwrap } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import type { CustomField, CustomFieldEntity } from '@/lib/types';
import { Button, IconButton } from './ui/Button';
import { Section } from './ui/Card';
import { Field, Input, Textarea } from './ui/Field';
import { Modal } from './ui/Modal';
import { FormError, Skeleton } from './ui/States';

interface CustomFieldsProps {
  propertyId: string;
  entityType: CustomFieldEntity;
  entityId: string;
}

/** User-defined "label: value" details for anything HomeHub doesn't have a field for. */
export function CustomFields({ propertyId, entityType, entityId }: CustomFieldsProps) {
  const toast = useToast();
  const [editing, setEditing] = useState<CustomField | 'new' | null>(null);

  const { data, loading, reload } = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('custom_fields')
          .select('*')
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .order('sort_order')
          .order('created_at'),
      ) as CustomField[],
    [entityType, entityId],
  );

  const remove = async (f: CustomField) => {
    try {
      await deleteRow('custom_fields', f.id);
      void reload();
    } catch (err) {
      toast.error(err);
    }
  };

  return (
    <Section
      title="Extra details"
      icon={ListPlus}
      description="Add anything else worth remembering."
      action={
        <Button variant="secondary" size="sm" icon={Plus} onClick={() => setEditing('new')}>
          Add
        </Button>
      }
    >
      {loading && !data ? (
        <Skeleton className="h-10" />
      ) : !data?.length ? (
        <p className="text-muted text-sm">For example: bin collection day, paint colours, Wi-Fi network name.</p>
      ) : (
        <ul className="divide-line divide-y">
          {data.map((f) => (
            <li key={f.id} className="flex items-start gap-2 py-2.5 first:pt-0 last:pb-0">
              <div className="min-w-0 flex-1">
                <p className="text-muted text-xs font-medium tracking-wide uppercase">{f.label}</p>
                <p className="text-ink mt-0.5 text-sm break-words whitespace-pre-line">{f.value || '—'}</p>
              </div>
              <IconButton icon={Pencil} label={`Edit ${f.label}`} onClick={() => setEditing(f)} />
              <IconButton icon={Trash2} label={`Delete ${f.label}`} tone="danger" onClick={() => remove(f)} />
            </li>
          ))}
        </ul>
      )}

      <CustomFieldModal
        field={editing}
        onClose={() => setEditing(null)}
        onSave={async (label, value) => {
          if (editing === 'new') {
            await insertRow('custom_fields', {
              property_id: propertyId,
              entity_type: entityType,
              entity_id: entityId,
              label,
              value,
              sort_order: data?.length ?? 0,
            });
          } else if (editing) {
            await updateRow('custom_fields', editing.id, { label, value });
          }
          void reload();
        }}
      />
    </Section>
  );
}

function CustomFieldModal({
  field,
  onClose,
  onSave,
}: {
  field: CustomField | 'new' | null;
  onClose: () => void;
  onSave: (label: string, value: string | null) => Promise<void>;
}) {
  const existing = field && field !== 'new' ? field : null;
  const [label, setLabel] = useState('');
  const [value, setValue] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [lastField, setLastField] = useState<typeof field>(null);

  // Reset the inputs whenever a different field is opened.
  if (field !== lastField) {
    setLastField(field);
    setLabel(existing?.label ?? '');
    setValue(existing?.value ?? '');
    setError(null);
  }

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!label.trim()) return setError('Please enter a label.');
    setBusy(true);
    try {
      await onSave(label.trim(), value.trim() || null);
      onClose();
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      open={Boolean(field)}
      onClose={onClose}
      title={existing ? 'Edit detail' : 'Add a detail'}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="custom-field-form" loading={busy}>
            Save
          </Button>
        </>
      }
    >
      <form id="custom-field-form" onSubmit={submit} className="space-y-4" noValidate>
        <FormError message={error} />
        <Field label="Label" required>
          {(a) => (
            <Input
              {...a}
              value={label}
              maxLength={80}
              placeholder="e.g. Bin collection"
              onChange={(e) => setLabel(e.target.value)}
            />
          )}
        </Field>
        <Field label="Value">
          {(a) => (
            <Textarea {...a} value={value} placeholder="e.g. Tuesday mornings" onChange={(e) => setValue(e.target.value)} />
          )}
        </Field>
      </form>
    </Modal>
  );
}
