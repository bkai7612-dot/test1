import { Pencil, Phone, PhoneCall, Plus, Siren, Trash2, Umbrella, UserRound } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { Button, IconButton } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { deleteRow, insertRow, updateRow } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { EMERGENCY_FIELDS } from '@/lib/fields';
import { telHref } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { EmergencyContact, HouseholdMember, InsurancePolicy } from '@/lib/types';
import { policyTitle } from './Insurance';

/** General UK numbers, shown for reference. Homefolio never dials anything itself. */
const NATIONAL_NUMBERS = [
  { label: 'Emergency services', number: '999', note: 'Police, fire, ambulance' },
  { label: 'Gas emergency', number: '0800 111 999', note: 'If you smell gas' },
  { label: 'Power cut', number: '105', note: 'Any network operator' },
  { label: 'NHS non-emergency', number: '111', note: 'Urgent medical advice' },
];

function CallRow({
  title,
  subtitle,
  phone,
  icon: Icon,
  actions,
}: {
  title: string;
  subtitle?: string | null;
  phone?: string | null;
  icon: typeof Phone;
  actions?: ReactNode;
}) {
  return (
    <li className="flex flex-wrap items-center gap-x-3 gap-y-1 py-3">
      <span className="bg-surface-muted text-muted flex size-10 shrink-0 items-center justify-center rounded-xl">
        <Icon className="size-5" aria-hidden />
      </span>
      <div className="min-w-[9rem] flex-1">
        <p className="text-ink truncate font-medium">{title}</p>
        {subtitle && <p className="text-muted truncate text-sm">{subtitle}</p>}
      </div>
      {phone && (
        <a
          href={telHref(phone)}
          className="bg-brand-50 text-brand-800 hover:bg-brand-100 dark:bg-brand-900/40 dark:text-brand-200 inline-flex min-h-10 shrink-0 items-center gap-1.5 rounded-xl px-3 text-sm font-semibold"
          aria-label={`Call ${title} on ${phone}`}
        >
          <PhoneCall className="size-4" aria-hidden />
          <span className="hidden sm:inline">{phone}</span>
          <span className="sm:hidden">Call</span>
        </a>
      )}
      {actions}
    </li>
  );
}

export default function Emergency() {
  const property = useActiveProperty();
  const toast = useToast();
  const editor = useEditor<EmergencyContact>();
  const [deleting, setDeleting] = useState<EmergencyContact | null>(null);

  const { data, loading, error, reload } = useQuery(async () => {
    const [contacts, members, policies] = await Promise.all([
      supabase.from('emergency_contacts').select('*').eq('property_id', property.id).order('contact_type').order('name'),
      supabase.from('household_members').select('*').eq('property_id', property.id).eq('is_emergency_contact', true),
      supabase.from('insurance_policies').select('*').eq('property_id', property.id).not('emergency_phone', 'is', null),
    ]);
    return {
      contacts: unwrap(contacts) as EmergencyContact[],
      members: unwrap(members) as HouseholdMember[],
      policies: unwrap(policies) as InsurancePolicy[],
    };
  }, [property.id]);

  const addButton = (
    <Button icon={Plus} onClick={editor.openNew}>
      Add contact
    </Button>
  );

  const hasPersonal = Boolean(data && (data.contacts.length || data.members.length || data.policies.length));

  return (
    <>
      <PageHeader
        title="Emergency"
        description="Important numbers for this home, ready when you need them."
        actions={addButton}
      />
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="space-y-4">
          {loading && !data ? (
            <ListSkeleton rows={3} />
          ) : error ? (
            <ErrorState error={error} onRetry={reload} />
          ) : !hasPersonal ? (
            <EmptyState
              icon={Phone}
              title="No emergency contacts yet"
              description="Add your landlord, building manager, plumber or utility emergency lines. Household members marked as emergency contacts also appear here."
              action={addButton}
            />
          ) : (
            <>
              {data!.members.length > 0 && (
                <Section title="People" icon={UserRound}>
                  <ul className="divide-line -my-3 divide-y">
                    {data!.members.map((m) => (
                      <CallRow key={m.id} icon={UserRound} title={m.name} subtitle={m.relationship} phone={m.phone} />
                    ))}
                  </ul>
                </Section>
              )}
              {data!.contacts.length > 0 && (
                <Section title="Important contacts" icon={Phone}>
                  <ul className="divide-line -my-3 divide-y">
                    {data!.contacts.map((c) => (
                      <CallRow
                        key={c.id}
                        icon={Phone}
                        title={c.name}
                        subtitle={[c.contact_type, c.alt_phone && `Alt: ${c.alt_phone}`, c.notes].filter(Boolean).join(' · ')}
                        phone={c.phone}
                        actions={
                          <span className="ml-auto flex">
                            <IconButton icon={Pencil} label={`Edit ${c.name}`} onClick={() => editor.openEdit(c)} />
                            <IconButton icon={Trash2} tone="danger" label={`Delete ${c.name}`} onClick={() => setDeleting(c)} />
                          </span>
                        }
                      />
                    ))}
                  </ul>
                </Section>
              )}
              {data!.policies.length > 0 && (
                <Section title="Insurance claims lines" icon={Umbrella}>
                  <ul className="divide-line -my-3 divide-y">
                    {data!.policies.map((p) => (
                      <CallRow
                        key={p.id}
                        icon={Umbrella}
                        title={policyTitle(p)}
                        subtitle={p.provider}
                        phone={p.emergency_phone}
                      />
                    ))}
                  </ul>
                </Section>
              )}
            </>
          )}
        </div>
        <Section
          title="National numbers (UK)"
          icon={Siren}
          description="Tap to call. Homefolio never calls anyone automatically."
          className="h-fit border-rose-200 dark:border-rose-900/60"
        >
          <ul className="divide-line -my-3 divide-y">
            {NATIONAL_NUMBERS.map((n) => (
              <CallRow key={n.number} icon={Siren} title={n.label} subtitle={n.note} phone={n.number} />
            ))}
          </ul>
        </Section>
      </div>

      <FormModal
        open={editor.isOpen}
        onClose={editor.close}
        title={editor.row ? 'Edit contact' : 'Add emergency contact'}
        fields={EMERGENCY_FIELDS}
        initial={toFormValues(EMERGENCY_FIELDS, editor.row)}
        onSubmit={async (payload) => {
          if (editor.row) await updateRow('emergency_contacts', editor.row.id, payload);
          else await insertRow('emergency_contacts', { ...payload, property_id: property.id });
          toast.success('Contact saved');
          editor.close();
          void reload();
        }}
      />
      <ConfirmDialog
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title={`Delete ${deleting?.name}?`}
        message="This contact will be removed."
        onConfirm={async () => {
          if (!deleting) return;
          await deleteRow('emergency_contacts', deleting.id);
          toast.success('Contact deleted');
          void reload();
        }}
      />
    </>
  );
}
