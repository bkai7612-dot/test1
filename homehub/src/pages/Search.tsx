import {
  DoorOpen,
  FileText,
  Package,
  Phone,
  SearchIcon,
  ShieldCheck,
  Umbrella,
  Users,
  WashingMachine,
  Wrench,
  Zap,
  type LucideIcon,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Tag } from '@/components/ui/Badges';
import { Chips, PageHeader, SearchInput } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useProperties } from '@/context/PropertyContext';
import { useDebounced } from '@/hooks/useData';
import { useQuery } from '@/hooks/useQuery';
import { unwrap } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import type { SearchKind, SearchResult } from '@/lib/types';

const KINDS: Record<SearchKind, { label: string; icon: LucideIcon; link: (id: string) => string }> = {
  appliance: { label: 'Appliances', icon: WashingMachine, link: (id) => `/appliances/${id}` },
  inventory: { label: 'Inventory', icon: Package, link: (id) => `/inventory/${id}` },
  document: { label: 'Documents', icon: FileText, link: (id) => `/documents?open=${id}` },
  maintenance: { label: 'Maintenance', icon: Wrench, link: (id) => `/maintenance/${id}` },
  warranty: { label: 'Warranties', icon: ShieldCheck, link: (id) => `/appliances/${id}` },
  inventory_warranty: { label: 'Warranties', icon: ShieldCheck, link: (id) => `/inventory/${id}` },
  room: { label: 'Rooms', icon: DoorOpen, link: (id) => `/rooms/${id}` },
  utility: { label: 'Utilities', icon: Zap, link: (id) => `/utilities/${id}` },
  insurance: { label: 'Insurance', icon: Umbrella, link: (id) => `/insurance/${id}` },
  contact: { label: 'Contacts', icon: Phone, link: () => '/emergency' },
  household: { label: 'Household', icon: Users, link: () => '/household' },
};

type Scope = 'property' | 'all';

export default function Search() {
  const { active, properties, setActive } = useProperties();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [scope, setScope] = useState<Scope>('property');
  const q = useDebounced(query.trim(), 250);
  const enabled = q.length >= 2;

  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(
        await supabase.rpc('search_home', { p_query: q, p_property_id: scope === 'property' ? (active?.id ?? null) : null }),
      ) as SearchResult[],
    [q, scope, active?.id],
    enabled,
  );

  const propertyName = useMemo(() => new Map(properties.map((p) => [p.id, p.name])), [properties]);
  const groups = useMemo(() => {
    const map = new Map<string, SearchResult[]>();
    for (const r of data ?? []) {
      const label = KINDS[r.kind]?.label ?? 'Other';
      map.set(label, [...(map.get(label) ?? []), r]);
    }
    return [...map.entries()];
  }, [data]);

  const open = (r: SearchResult) => {
    if (r.property_id !== active?.id) setActive(r.property_id);
    navigate(KINDS[r.kind].link(r.item_id));
  };

  return (
    <>
      <PageHeader
        title="Search"
        description="Find anything across your home — appliances, documents, tasks, contacts and more."
      />
      <div className="mb-5 space-y-3">
        <SearchInput
          value={query}
          onChange={setQuery}
          placeholder="Try “Samsung” or “boiler”"
          label="Search your home"
          autoFocus
        />
        {properties.length > 1 && (
          <Chips
            label="Search in"
            value={scope}
            onChange={setScope}
            options={[
              { value: 'property', label: active ? `In ${active.name}` : 'This property' },
              { value: 'all', label: 'All properties' },
            ]}
          />
        )}
      </div>
      {!enabled ? (
        <EmptyState compact icon={SearchIcon} title="Start typing to search" description="Type at least 2 characters." />
      ) : loading && !data ? (
        <ListSkeleton rows={3} />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !data?.length ? (
        <EmptyState
          compact
          icon={SearchIcon}
          title={`No results for “${q}”`}
          description="Check the spelling or try a different word."
        />
      ) : (
        <div className="space-y-6" aria-live="polite">
          {groups.map(([label, results]) => (
            <section key={label} aria-labelledby={`s-${label}`}>
              <h2 id={`s-${label}`} className="text-muted mb-2 text-sm font-semibold tracking-wide uppercase">
                {label}
              </h2>
              <ul className="space-y-2">
                {results.map((r) => {
                  const Icon = KINDS[r.kind]?.icon ?? SearchIcon;
                  return (
                    <li key={`${r.kind}-${r.item_id}`}>
                      <button
                        type="button"
                        onClick={() => open(r)}
                        className="border-line bg-surface hover:border-brand-300 flex w-full items-center gap-3 rounded-2xl border p-3 text-left transition-colors"
                      >
                        <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-10 shrink-0 items-center justify-center rounded-xl">
                          <Icon className="size-5" aria-hidden />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="text-ink block truncate font-medium">{r.title}</span>
                          {r.subtitle && <span className="text-muted block truncate text-sm">{r.subtitle}</span>}
                        </span>
                        {scope === 'all' && <Tag>{propertyName.get(r.property_id)}</Tag>}
                      </button>
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}
        </div>
      )}
    </>
  );
}
