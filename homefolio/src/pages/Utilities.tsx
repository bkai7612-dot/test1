import { Phone, Plus, Zap } from 'lucide-react';
import { SponsoredCard } from '@/components/SponsoredCard';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { StatusBadge } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { insertRow, updateRow } from '@/lib/api';
import { DEFAULT_CATEGORIES } from '@/lib/constants';
import { unwrap } from '@/lib/errors';
import { UTILITY_FIELDS } from '@/lib/fields';
import { formatDate, formatMoney, telHref, titleCase } from '@/lib/format';
import { utilityIcon } from '@/lib/icons';
import { renewalStatus } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { Utility } from '@/lib/types';

export function UtilityFormModal({
  open,
  onClose,
  propertyId,
  utility,
  defaultType,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  propertyId: string;
  utility?: Utility | null;
  defaultType?: string;
  onSaved: (u: Utility) => void;
}) {
  const toast = useToast();
  return (
    <FormModal
      open={open}
      onClose={onClose}
      title={utility ? `Edit ${titleCase(utility.utility_type)}` : 'Add utility or service'}
      description="Just for your records — Homefolio doesn't connect to your providers."
      fields={UTILITY_FIELDS}
      initial={toFormValues(UTILITY_FIELDS, utility, { utility_type: defaultType ?? '' })}
      extraValidate={(v) =>
        v.contract_start && v.contract_end && v.contract_end < v.contract_start
          ? { contract_end: 'Contract end must be after the start.' }
          : {}
      }
      onSubmit={async (payload) => {
        const saved = utility
          ? await updateRow<Utility>('utilities', utility.id, payload)
          : await insertRow<Utility>('utilities', { ...payload, property_id: propertyId });
        toast.success(utility ? 'Changes saved' : `${titleCase(saved.utility_type)} added`);
        onSaved(saved);
        onClose();
      }}
    />
  );
}

export default function Utilities() {
  const property = useActiveProperty();
  const editor = useEditor<Utility>();
  const [defaultType, setDefaultType] = useState<string>();
  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(await supabase.from('utilities').select('*').eq('property_id', property.id).order('created_at')) as Utility[],
    [property.id],
  );

  const have = new Set((data ?? []).map((u) => u.utility_type.toLowerCase()));
  const missing = DEFAULT_CATEGORIES.utility.filter((t) => !have.has(t.toLowerCase()));
  const openNew = (type?: string) => {
    setDefaultType(type);
    editor.openNew();
  };

  return (
    <>
      <PageHeader
        title="Utilities"
        description="Energy, water, broadband and other services for this home."
        actions={
          <Button icon={Plus} onClick={() => openNew()}>
            Add
          </Button>
        }
      />
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : (
        <>
          {!data?.length && (
            <div className="mb-4">
              <EmptyState
                icon={Zap}
                title="No utilities yet"
                description="Store your providers, account numbers and contract dates so they're easy to find when you need them."
              />
            </div>
          )}
          <ul className="grid grid-cols-1 gap-3 md:grid-cols-2">
            {data?.map((u) => {
              const Icon = utilityIcon(u.utility_type);
              const status = renewalStatus(u.contract_end, 60);
              return (
                <li key={u.id} className="border-line bg-surface flex flex-col rounded-2xl border">
                  <Link
                    to={`/utilities/${u.id}`}
                    className="hover:bg-surface-muted/40 flex flex-1 items-start gap-3 rounded-2xl p-4"
                  >
                    <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-11 shrink-0 items-center justify-center rounded-xl">
                      <Icon className="size-5" aria-hidden />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="text-muted block text-xs font-medium tracking-wide uppercase">
                        {titleCase(u.utility_type)}
                      </span>
                      <span className="text-ink block truncate font-semibold">{u.provider || 'Provider not set'}</span>
                      <span className="text-muted mt-1 block truncate text-sm">
                        {[
                          u.tariff,
                          u.account_number && `Acc. ${u.account_number}`,
                          u.monthly_cost !== null && `${formatMoney(u.monthly_cost)}/month`,
                        ]
                          .filter(Boolean)
                          .join(' · ') || 'Tap to add details'}
                      </span>
                      {u.contract_end && (
                        <span className="mt-2 flex">
                          <StatusBadge
                            status={status === 'active' ? 'upcoming' : status}
                            label={`${status === 'expired' ? 'Contract ended' : 'Contract ends'} ${formatDate(u.contract_end, 'short')}`}
                          />
                        </span>
                      )}
                    </span>
                  </Link>
                  {u.contact_phone && (
                    <a
                      href={telHref(u.contact_phone)}
                      className="border-line text-brand-fg hover:bg-surface-muted/40 flex min-h-11 items-center gap-2 border-t px-4 text-sm font-medium"
                    >
                      <Phone className="size-4" aria-hidden /> {u.contact_phone}
                    </a>
                  )}
                </li>
              );
            })}
            {missing.map((type) => {
              const Icon = utilityIcon(type);
              return (
                <li key={type}>
                  <button
                    type="button"
                    onClick={() => openNew(type)}
                    className="border-line text-muted hover:border-brand-400 hover:text-ink flex h-full min-h-20 w-full items-center gap-3 rounded-2xl border border-dashed p-4 text-left transition-colors"
                  >
                    <span className="bg-surface-muted flex size-11 shrink-0 items-center justify-center rounded-xl">
                      <Icon className="size-5" aria-hidden />
                    </span>
                    <span className="font-medium">Add {type.toLowerCase()}</span>
                    <Plus className="ml-auto size-4" aria-hidden />
                  </button>
                </li>
              );
            })}
          </ul>
        </>
      )}
      <SponsoredCard placement="utilities" className="mt-6" />
      <UtilityFormModal
        open={editor.isOpen}
        onClose={editor.close}
        propertyId={property.id}
        utility={editor.row}
        defaultType={defaultType}
        onSaved={() => void reload()}
      />
    </>
  );
}
