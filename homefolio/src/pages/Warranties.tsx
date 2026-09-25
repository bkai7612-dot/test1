import { ShieldCheck } from 'lucide-react';
import { useMemo, useState } from 'react';
import { StatusBadge } from '@/components/ui/Badges';
import { LinkButton } from '@/components/ui/Button';
import { ListCard } from '@/components/ui/Card';
import { Chips, Grid, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useQuery } from '@/hooks/useQuery';
import { unwrap } from '@/lib/errors';
import { daysUntil, formatDate, relativeDays } from '@/lib/format';
import { warrantyStatus, type Status } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { Warranty } from '@/lib/types';

type Row = Warranty & {
  appliance: { name: string; retailer: string | null } | null;
  inventory: { name: string; retailer: string | null } | null;
};

type Filter = 'all' | 'active' | 'expiring' | 'expired';

export default function Warranties() {
  const property = useActiveProperty();
  const [filter, setFilter] = useState<Filter>('all');
  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('warranties')
          .select('*, appliance:appliances(name, retailer), inventory:inventory_items(name, retailer)')
          .eq('property_id', property.id)
          .order('expiry_date', { ascending: true, nullsFirst: false }),
      ) as Row[],
    [property.id],
  );

  const rows = useMemo(() => (data ?? []).map((w) => ({ ...w, status: warrantyStatus(w.expiry_date) as Status })), [data]);
  const count = (s: Filter) => rows.filter((r) => s === 'all' || r.status === s).length;
  const visible = rows.filter((r) => filter === 'all' || r.status === filter);

  return (
    <>
      <PageHeader title="Warranties" description="See what's still covered and what's running out." />
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !rows.length ? (
        <EmptyState
          icon={ShieldCheck}
          title="No warranties yet"
          description="Add warranty dates to your appliances or inventory items and they'll show here, with reminders before they expire."
          action={<LinkButton to="/appliances">Go to appliances</LinkButton>}
        />
      ) : (
        <>
          <div className="mb-4">
            <Chips
              label="Filter warranties"
              value={filter}
              onChange={setFilter}
              options={[
                { value: 'all', label: 'All', count: count('all') },
                { value: 'active', label: 'Active', count: count('active') },
                { value: 'expiring', label: 'Expiring soon', count: count('expiring') },
                { value: 'expired', label: 'Expired', count: count('expired') },
              ]}
            />
          </div>
          {!visible.length ? (
            <EmptyState compact icon={ShieldCheck} title="Nothing here" description="No warranties match this filter." />
          ) : (
            <Grid>
              {visible.map((w) => {
                const parent = w.appliance ?? w.inventory;
                const to = w.appliance_id ? `/appliances/${w.appliance_id}` : `/inventory/${w.inventory_item_id}`;
                const days = w.expiry_date ? daysUntil(w.expiry_date) : null;
                return (
                  <ListCard
                    key={w.id}
                    to={to}
                    icon={ShieldCheck}
                    title={parent?.name ?? 'Item'}
                    subtitle={
                      w.expiry_date
                        ? `${days !== null && days < 0 ? 'Expired' : 'Expires'} ${formatDate(w.expiry_date)} (${relativeDays(days ?? 0)})`
                        : 'No expiry date'
                    }
                    meta={
                      <>
                        <StatusBadge status={w.status} />
                        {w.provider && <span className="text-muted text-xs">{w.provider}</span>}
                      </>
                    }
                  />
                );
              })}
            </Grid>
          )}
        </>
      )}
    </>
  );
}
