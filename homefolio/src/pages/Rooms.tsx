import { DoorOpen, Plus } from 'lucide-react';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { Tag } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { ListCard } from '@/components/ui/Card';
import { Grid, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { insertRow, updateRow } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { ROOM_FIELDS } from '@/lib/fields';
import { roomIcon } from '@/lib/icons';
import { supabase } from '@/lib/supabase';
import type { Room } from '@/lib/types';

type RoomWithCounts = Room & { appliances: { count: number }[]; inventory_items: { count: number }[] };

export function RoomFormModal({
  open,
  onClose,
  room,
  propertyId,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  room?: Room | null;
  propertyId: string;
  onSaved: (room: Room) => void;
}) {
  const toast = useToast();
  return (
    <FormModal
      open={open}
      onClose={onClose}
      title={room ? 'Edit room' : 'Add a room'}
      size="md"
      fields={ROOM_FIELDS}
      initial={toFormValues(ROOM_FIELDS, room)}
      onSubmit={async (payload) => {
        // Default the name to the chosen type so "Kitchen" takes one tap.
        const values = { ...payload, name: payload.name || payload.room_type };
        const saved = room
          ? await updateRow<Room>('rooms', room.id, values)
          : await insertRow<Room>('rooms', { ...values, property_id: propertyId });
        toast.success(room ? 'Room updated' : `${saved.name} added`);
        onSaved(saved);
        onClose();
      }}
      extraValidate={(v) => (!v.name && !v.room_type ? { name: 'Please give the room a name.' } : {})}
    />
  );
}

export default function Rooms() {
  const property = useActiveProperty();
  const editor = useEditor<Room>();
  const { data, loading, error, reload } = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('rooms')
          .select('*, appliances(count), inventory_items(count)')
          .eq('property_id', property.id)
          .order('name'),
      ) as RoomWithCounts[],
    [property.id],
  );

  return (
    <>
      <PageHeader
        title="Rooms"
        description={`Organise ${property.name} room by room.`}
        actions={
          <Button icon={Plus} onClick={editor.openNew}>
            Add room
          </Button>
        }
      />
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !data?.length ? (
        <EmptyState
          icon={DoorOpen}
          title="No rooms yet"
          description="Add rooms to see what's where — appliances, possessions, photos and notes."
          action={
            <Button icon={Plus} onClick={editor.openNew}>
              Add room
            </Button>
          }
        />
      ) : (
        <Grid>
          {data.map((r) => {
            const appliances = r.appliances[0]?.count ?? 0;
            const items = r.inventory_items[0]?.count ?? 0;
            return (
              <ListCard
                key={r.id}
                to={`/rooms/${r.id}`}
                icon={roomIcon(r.room_type)}
                title={r.name}
                subtitle={r.room_type && r.room_type !== r.name ? r.room_type : undefined}
                meta={
                  <>
                    <Tag>
                      {appliances} {appliances === 1 ? 'appliance' : 'appliances'}
                    </Tag>
                    <Tag>
                      {items} {items === 1 ? 'item' : 'items'}
                    </Tag>
                  </>
                }
              />
            );
          })}
        </Grid>
      )}
      <RoomFormModal
        open={editor.isOpen}
        onClose={editor.close}
        room={editor.row}
        propertyId={property.id}
        onSaved={() => void reload()}
      />
    </>
  );
}
