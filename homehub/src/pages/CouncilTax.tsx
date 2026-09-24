import { Landmark, Pencil, Plus } from 'lucide-react';
import { useState } from 'react';
import { DocumentsPanel } from '@/components/files/DocumentsPanel';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { DetailList, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useQuery } from '@/hooks/useQuery';
import { insertRow, updateRow } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { COUNCIL_TAX_FIELDS } from '@/lib/fields';
import { formatMoney } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { CouncilTax as CouncilTaxRow } from '@/lib/types';

function ordinal(n: number): string {
  const s = ['th', 'st', 'nd', 'rd'];
  const v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]);
}

export default function CouncilTax() {
  const property = useActiveProperty();
  const toast = useToast();
  const [editing, setEditing] = useState(false);
  const { data, loading, error, reload, setData } = useQuery(
    async () =>
      unwrap(await supabase.from('council_tax').select('*').eq('property_id', property.id).maybeSingle()) as CouncilTaxRow | null,
    [property.id],
  );
  const record = data ?? null;

  return (
    <>
      <PageHeader
        title="Council tax"
        description={`Your council tax details for ${property.name}.`}
        actions={
          record && (
            <Button variant="secondary" icon={Pencil} onClick={() => setEditing(true)}>
              Edit
            </Button>
          )
        }
      />
      {loading && data === undefined ? (
        <ListSkeleton rows={2} />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !record ? (
        <EmptyState
          icon={Landmark}
          title="No council tax details yet"
          description="Keep your council, account number, band and payment date handy."
          action={
            <Button icon={Plus} onClick={() => setEditing(true)}>
              Add council tax details
            </Button>
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <Section title="Details" icon={Landmark}>
            <DetailList
              items={[
                { label: 'Council', value: record.council, full: true },
                { label: 'Account / reference', value: record.account_number },
                { label: 'Band', value: record.band },
                { label: 'Monthly amount', value: formatMoney(record.monthly_amount) },
                { label: 'Payment date', value: record.payment_day ? `${ordinal(record.payment_day)} of each month` : null },
                { label: 'Property', value: property.name },
                { label: 'Notes', value: record.notes, full: true },
              ]}
            />
          </Section>
          <DocumentsPanel
            propertyId={property.id}
            link={{ key: 'council_tax_id', id: record.id }}
            title="Bills & letters"
            defaultCategory="Property"
            emptyText="Upload your annual bill or any letters from the council."
          />
        </div>
      )}
      <FormModal
        open={editing}
        onClose={() => setEditing(false)}
        title={record ? 'Edit council tax' : 'Add council tax details'}
        fields={COUNCIL_TAX_FIELDS}
        initial={toFormValues(COUNCIL_TAX_FIELDS, record)}
        onSubmit={async (payload) => {
          const saved = record
            ? await updateRow<CouncilTaxRow>('council_tax', record.id, payload)
            : await insertRow<CouncilTaxRow>('council_tax', { ...payload, property_id: property.id });
          setData(saved);
          toast.success('Council tax details saved');
          setEditing(false);
        }}
      />
    </>
  );
}
