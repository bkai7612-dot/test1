import { Mail, Pencil, Phone, Plus, Trash2, UserRound, Users } from 'lucide-react';
import { useState } from 'react';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { StatusBadge } from '@/components/ui/Badges';
import { Button, IconButton } from '@/components/ui/Button';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { deleteRow, insertRow, updateRow } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { HOUSEHOLD_FIELDS } from '@/lib/fields';
import { telHref } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { HouseholdMember } from '@/lib/types';

export default function Household() {
  const property = useActiveProperty();
  const toast = useToast();
  const editor = useEditor<HouseholdMember>();
  const [deleting, setDeleting] = useState<HouseholdMember | null>(null);
  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(
        await supabase.from('household_members').select('*').eq('property_id', property.id).order('created_at'),
      ) as HouseholdMember[],
    [property.id],
  );

  const addButton = (
    <Button icon={Plus} onClick={editor.openNew}>
      Add person
    </Button>
  );

  return (
    <>
      <PageHeader title="Household" description={`The people who live at ${property.name}.`} actions={addButton} />
      {loading && !data ? (
        <ListSkeleton rows={2} />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !data?.length ? (
        <EmptyState
          icon={Users}
          title="No household members yet"
          description="Add the people you live with and their contact details. Mark anyone who should be an emergency contact."
          action={addButton}
        />
      ) : (
        <ul className="grid grid-cols-1 gap-3 md:grid-cols-2">
          {data.map((m) => (
            <li key={m.id} className="border-line bg-surface rounded-2xl border p-4">
              <div className="flex items-start gap-3">
                <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-11 shrink-0 items-center justify-center rounded-full">
                  <UserRound className="size-5" aria-hidden />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-ink truncate font-semibold">{m.name}</p>
                  {m.relationship && <p className="text-muted text-sm">{m.relationship}</p>}
                  {m.is_emergency_contact && (
                    <span className="mt-1.5 inline-flex">
                      <StatusBadge status="active" label="Emergency contact" />
                    </span>
                  )}
                </div>
                <IconButton icon={Pencil} label={`Edit ${m.name}`} onClick={() => editor.openEdit(m)} />
                <IconButton icon={Trash2} tone="danger" label={`Remove ${m.name}`} onClick={() => setDeleting(m)} />
              </div>
              {(m.phone || m.email) && (
                <div className="border-line mt-3 flex flex-wrap gap-2 border-t pt-3">
                  {m.phone && (
                    <a
                      href={telHref(m.phone)}
                      className="text-brand-fg hover:bg-surface-muted inline-flex min-h-9 items-center gap-1.5 rounded-lg px-2 text-sm font-medium"
                    >
                      <Phone className="size-4" aria-hidden /> {m.phone}
                    </a>
                  )}
                  {m.email && (
                    <a
                      href={`mailto:${m.email}`}
                      className="text-brand-fg hover:bg-surface-muted inline-flex min-h-9 min-w-0 items-center gap-1.5 rounded-lg px-2 text-sm font-medium"
                    >
                      <Mail className="size-4 shrink-0" aria-hidden /> <span className="truncate">{m.email}</span>
                    </a>
                  )}
                </div>
              )}
              {m.notes && <p className="text-muted mt-3 text-sm whitespace-pre-line">{m.notes}</p>}
            </li>
          ))}
        </ul>
      )}
      <FormModal
        open={editor.isOpen}
        onClose={editor.close}
        title={editor.row ? `Edit ${editor.row.name}` : 'Add household member'}
        fields={HOUSEHOLD_FIELDS}
        initial={toFormValues(HOUSEHOLD_FIELDS, editor.row)}
        onSubmit={async (payload) => {
          if (editor.row) await updateRow('household_members', editor.row.id, payload);
          else await insertRow('household_members', { ...payload, property_id: property.id });
          toast.success('Saved');
          editor.close();
          void reload();
        }}
      />
      <ConfirmDialog
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title={`Remove ${deleting?.name}?`}
        message="Their details will be deleted from this property."
        confirmLabel="Remove"
        onConfirm={async () => {
          if (!deleting) return;
          await deleteRow('household_members', deleting.id);
          toast.success('Removed');
          void reload();
        }}
      />
    </>
  );
}
