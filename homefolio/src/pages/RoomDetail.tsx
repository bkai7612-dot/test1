import { Package, Pencil, Plus, StickyNote, Trash2, WashingMachine } from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { CustomFields } from '@/components/CustomFields';
import { DetailScaffold, useRecord } from '@/components/DetailScaffold';
import { DocumentsPanel } from '@/components/files/DocumentsPanel';
import { PhotoGallery } from '@/components/files/PhotoGallery';
import { Button, LinkButton } from '@/components/ui/Button';
import { ListCard, Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { PageHeader } from '@/components/ui/Layout';
import { Skeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useQuery } from '@/hooks/useQuery';
import { deleteWithPhotos } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { itemIcon } from '@/lib/icons';
import { supabase } from '@/lib/supabase';
import type { Room } from '@/lib/types';
import { RoomFormModal } from './Rooms';

interface ItemSummary {
  id: string;
  name: string;
  category: string | null;
  brand: string | null;
}

function RoomItems({
  roomId,
  table,
  title,
  icon,
  basePath,
  emptyText,
}: {
  roomId: string;
  table: 'appliances' | 'inventory_items';
  title: string;
  icon: typeof Package;
  basePath: string;
  emptyText: string;
}) {
  const { data, loading } = useQuery(
    async () =>
      unwrap(await supabase.from(table).select('id, name, category, brand').eq('room_id', roomId).order('name')) as ItemSummary[],
    [roomId, table],
  );
  return (
    <Section
      title={title}
      icon={icon}
      action={
        <LinkButton to={`${basePath}?new=1&room=${roomId}`} variant="secondary" size="sm" icon={Plus}>
          Add
        </LinkButton>
      }
    >
      {loading && !data ? (
        <Skeleton className="h-16" />
      ) : !data?.length ? (
        <p className="text-muted text-sm">{emptyText}</p>
      ) : (
        <ul className="space-y-2">
          {data.map((i) => (
            <li key={i.id}>
              <ListCard
                to={`${basePath}/${i.id}`}
                icon={itemIcon(i.category, icon)}
                title={i.name}
                subtitle={[i.brand, i.category].filter(Boolean).join(' · ')}
              />
            </li>
          ))}
        </ul>
      )}
    </Section>
  );
}

export default function RoomDetail() {
  const { id } = useParams();
  const property = useActiveProperty();
  const state = useRecord<Room>('rooms', id);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const navigate = useNavigate();
  const toast = useToast();

  return (
    <DetailScaffold state={state} backTo="/rooms" backLabel="Rooms" propertyId={property.id}>
      {(room) => (
        <>
          <PageHeader
            back={{ to: '/rooms', label: 'Rooms' }}
            title={room.name}
            description={room.room_type && room.room_type !== room.name ? room.room_type : undefined}
            actions={
              <>
                <Button variant="secondary" icon={Pencil} onClick={() => setEditing(true)}>
                  Edit
                </Button>
                <Button variant="secondary" icon={Trash2} onClick={() => setDeleting(true)}>
                  Delete
                </Button>
              </>
            }
          />
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            <div className="space-y-4">
              {room.notes && (
                <Section title="Notes" icon={StickyNote}>
                  <p className="text-ink text-sm whitespace-pre-line">{room.notes}</p>
                </Section>
              )}
              <RoomItems
                roomId={room.id}
                table="appliances"
                title="Appliances"
                icon={WashingMachine}
                basePath="/appliances"
                emptyText="No appliances in this room yet."
              />
              <RoomItems
                roomId={room.id}
                table="inventory_items"
                title="Inventory"
                icon={Package}
                basePath="/inventory"
                emptyText="No inventory items in this room yet."
              />
              <CustomFields propertyId={property.id} entityType="room" entityId={room.id} />
            </div>
            <div className="space-y-4">
              <PhotoGallery propertyId={property.id} link={{ key: 'room_id', id: room.id }} itemName={room.name} />
              <DocumentsPanel
                propertyId={property.id}
                link={{ key: 'room_id', id: room.id }}
                title="Documents"
                defaultCategory="Property"
              />
            </div>
          </div>

          <RoomFormModal
            open={editing}
            onClose={() => setEditing(false)}
            room={room}
            propertyId={property.id}
            onSaved={(r) => state.setData(r)}
          />
          <ConfirmDialog
            open={deleting}
            onClose={() => setDeleting(false)}
            title={`Delete ${room.name}?`}
            message="The room and its photos will be deleted. Appliances, inventory and documents in this room are kept, just no longer assigned to a room."
            onConfirm={async () => {
              await deleteWithPhotos('rooms', room.id, 'room_id');
              toast.success('Room deleted');
              navigate('/rooms', { replace: true });
            }}
          />
        </>
      )}
    </DetailScaffold>
  );
}
