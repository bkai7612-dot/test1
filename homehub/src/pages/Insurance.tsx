import { Plus, Umbrella } from 'lucide-react';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { StatusBadge } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { ListCard } from '@/components/ui/Card';
import { Grid, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { insertRow, updateRow } from '@/lib/api';
import { INSURANCE_TYPES } from '@/lib/constants';
import { unwrap } from '@/lib/errors';
import { INSURANCE_FIELDS } from '@/lib/fields';
import { daysUntil, formatDate, formatMoney, labelFor, relativeDays } from '@/lib/format';
import { renewalStatus, type Status } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { InsurancePolicy } from '@/lib/types';

export function policyTitle(p: InsurancePolicy): string {
  return `${labelFor(INSURANCE_TYPES, p.policy_type).replace(/ \(.*\)/, '')} insurance`;
}

export function renewalBadge(p: InsurancePolicy): { status: Status; label: string } | null {
  if (!p.renewal_date) return null;
  const status = renewalStatus(p.renewal_date, 30);
  const days = daysUntil(p.renewal_date);
  if (status === 'expired') return { status, label: `Renewal passed ${formatDate(p.renewal_date, 'short')}` };
  return { status: status === 'due' ? 'due' : 'upcoming', label: `Renews ${relativeDays(days)}` };
}

export function InsuranceFormModal({
  open,
  onClose,
  propertyId,
  policy,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  propertyId: string;
  policy?: InsurancePolicy | null;
  onSaved: (p: InsurancePolicy) => void;
}) {
  const toast = useToast();
  return (
    <FormModal
      open={open}
      onClose={onClose}
      title={policy ? 'Edit policy' : 'Add insurance policy'}
      fields={INSURANCE_FIELDS}
      initial={toFormValues(INSURANCE_FIELDS, policy, { policy_type: 'home', premium_frequency: 'yearly' })}
      onSubmit={async (payload) => {
        const saved = policy
          ? await updateRow<InsurancePolicy>('insurance_policies', policy.id, payload)
          : await insertRow<InsurancePolicy>('insurance_policies', { ...payload, property_id: propertyId });
        toast.success(policy ? 'Policy updated' : 'Policy added');
        onSaved(saved);
        onClose();
      }}
    />
  );
}

export default function Insurance() {
  const property = useActiveProperty();
  const editor = useEditor<InsurancePolicy>();
  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('insurance_policies')
          .select('*')
          .eq('property_id', property.id)
          .order('renewal_date', { ascending: true, nullsFirst: false }),
      ) as InsurancePolicy[],
    [property.id],
  );

  const addButton = (
    <Button icon={Plus} onClick={editor.openNew}>
      Add policy
    </Button>
  );

  return (
    <>
      <PageHeader title="Insurance" description="Policies, renewal dates and who to call." actions={addButton} />
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !data?.length ? (
        <EmptyState
          icon={Umbrella}
          title="No insurance policies yet"
          description="Add your home, contents or buildings insurance and we'll remind you before renewal."
          action={addButton}
        />
      ) : (
        <Grid>
          {data.map((p) => {
            const badge = renewalBadge(p);
            return (
              <ListCard
                key={p.id}
                to={`/insurance/${p.id}`}
                icon={Umbrella}
                title={policyTitle(p)}
                subtitle={
                  [
                    p.provider,
                    p.premium !== null &&
                      `${formatMoney(p.premium)} ${p.premium_frequency === 'monthly' ? 'per month' : 'per year'}`,
                  ]
                    .filter(Boolean)
                    .join(' · ') || undefined
                }
                meta={badge && <StatusBadge status={badge.status} label={badge.label} />}
              />
            );
          })}
        </Grid>
      )}
      <InsuranceFormModal
        open={editor.isOpen}
        onClose={editor.close}
        propertyId={property.id}
        policy={editor.row}
        onSaved={() => void reload()}
      />
    </>
  );
}
