import { Plus } from 'lucide-react';
import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { StatusBadge, Tag } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { ListCard } from '@/components/ui/Card';
import { Select } from '@/components/ui/Field';
import { Grid, PageHeader, SearchInput } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useRooms } from '@/hooks/useData';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { unwrap } from '@/lib/errors';
import { formatDate, formatMoney } from '@/lib/format';
import { itemIcon } from '@/lib/icons';
import { warrantyStatus } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { Appliance, InventoryItem } from '@/lib/types';
import { ITEM_CONFIG, type ItemKind } from './itemConfig';
import { ItemFormModal } from './ItemFormModal';

type Row = (Appliance | InventoryItem) & { warranties: { expiry_date: string | null }[] };

export default function ItemsList({ kind }: { kind: ItemKind }) {
  const cfg = ITEM_CONFIG[kind];
  const property = useActiveProperty();
  const editor = useEditor<Row>();
  const [params] = useSearchParams();
  const [defaultRoom] = useState(() => params.get('room'));
  const [search, setSearch] = useState('');
  const [room, setRoom] = useState('');
  const [category, setCategory] = useState('');
  const { data: rooms } = useRooms(property.id);

  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(
        await supabase.from(cfg.table).select('*, warranties(expiry_date)').eq('property_id', property.id).order('name'),
      ) as Row[],
    [property.id, cfg.table],
  );

  const roomName = useMemo(() => new Map((rooms ?? []).map((r) => [r.id, r.name])), [rooms]);
  const categories = useMemo(() => [...new Set((data ?? []).map((i) => i.category).filter(Boolean) as string[])].sort(), [data]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (data ?? []).filter(
      (i) =>
        (!room || i.room_id === room) &&
        (!category || i.category === category) &&
        (!q || [i.name, i.brand, i.model, i.category, i.serial_number].some((v) => v?.toLowerCase().includes(q))),
    );
  }, [data, search, room, category]);

  const totalValue =
    kind === 'inventory'
      ? (data ?? []).reduce((sum, i) => sum + Number((i as InventoryItem).current_value ?? i.purchase_price ?? 0), 0)
      : 0;

  const addButton = (
    <Button icon={Plus} onClick={editor.openNew}>
      Add {cfg.singular}
    </Button>
  );

  return (
    <>
      <PageHeader
        title={cfg.plural}
        description={
          kind === 'inventory' && totalValue > 0
            ? `${data?.length ?? 0} items · estimated value ${formatMoney(totalValue)}`
            : `${data?.length ?? 0} in ${property.name}`
        }
        actions={addButton}
      />
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !data?.length ? (
        <EmptyState icon={cfg.icon} title={`No ${cfg.plural.toLowerCase()} yet`} description={cfg.emptyText} action={addButton} />
      ) : (
        <>
          <div className="mb-4 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_auto_auto]">
            <SearchInput value={search} onChange={setSearch} placeholder={`Search ${cfg.plural.toLowerCase()}`} />
            <Select value={room} onChange={(e) => setRoom(e.target.value)} aria-label="Filter by room">
              <option value="">All rooms</option>
              {rooms?.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </Select>
            <Select value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Filter by category">
              <option value="">All categories</option>
              {categories.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </Select>
          </div>
          {filtered.length === 0 ? (
            <EmptyState compact icon={cfg.icon} title="No matches" description="Try a different search or filter." />
          ) : (
            <Grid>
              {filtered.map((i) => {
                const expiry = i.warranties[0]?.expiry_date;
                const status = warrantyStatus(expiry);
                return (
                  <ListCard
                    key={i.id}
                    to={`${cfg.path}/${i.id}`}
                    icon={itemIcon(i.category, cfg.icon)}
                    title={i.name}
                    subtitle={[i.brand, i.model].filter(Boolean).join(' ') || i.category || undefined}
                    meta={
                      <>
                        {i.room_id && roomName.get(i.room_id) && <Tag>{roomName.get(i.room_id)}</Tag>}
                        {status !== 'none' && (
                          <StatusBadge
                            status={status}
                            label={status === 'expired' ? 'Warranty expired' : `Warranty to ${formatDate(expiry, 'short')}`}
                          />
                        )}
                      </>
                    }
                  />
                );
              })}
            </Grid>
          )}
        </>
      )}
      <ItemFormModal
        kind={kind}
        open={editor.isOpen}
        onClose={editor.close}
        propertyId={property.id}
        item={editor.row}
        defaultRoomId={defaultRoom}
        onSaved={() => void reload()}
      />
    </>
  );
}
