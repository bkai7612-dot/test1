import { Info, Pencil, Plus, ShieldCheck, Trash2, Wrench } from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { CustomFields } from '@/components/CustomFields';
import { DetailScaffold, useRecord } from '@/components/DetailScaffold';
import { DocumentsPanel } from '@/components/files/DocumentsPanel';
import { PhotoGallery } from '@/components/files/PhotoGallery';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { StatusBadge } from '@/components/ui/Badges';
import { Button, IconButton, LinkButton } from '@/components/ui/Button';
import { ListCard, Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { DetailList, PageHeader } from '@/components/ui/Layout';
import { Skeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useRooms } from '@/hooks/useData';
import { useQuery } from '@/hooks/useQuery';
import { deleteRow, deleteWithPhotos } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { WARRANTY_ONLY_FIELDS } from '@/lib/fields';
import { daysUntil, formatDate, formatMoney, relativeDays } from '@/lib/format';
import { taskStatus, warrantyStatus } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { Appliance, InventoryItem, MaintenanceTask, Warranty } from '@/lib/types';
import { ITEM_CONFIG, type ItemKind } from './itemConfig';
import { ItemFormModal, saveWarranty } from './ItemFormModal';

type Item = Appliance | InventoryItem;

function WarrantyCard({ kind, item, propertyId }: { kind: ItemKind; item: Item; propertyId: string }) {
  const cfg = ITEM_CONFIG[kind];
  const toast = useToast();
  const [editing, setEditing] = useState(false);
  const [removing, setRemoving] = useState(false);
  const { data, loading, setData } = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('warranties')
          .select('*')
          .eq(cfg.warrantyKey, item.id)
          .order('expiry_date', { ascending: false })
          .limit(1)
          .maybeSingle(),
      ) as Warranty | null,
    [item.id],
  );
  const warranty = data ?? null;
  const status = warrantyStatus(warranty?.expiry_date);
  const days = warranty?.expiry_date ? daysUntil(warranty.expiry_date) : null;

  return (
    <Section
      title="Warranty"
      icon={ShieldCheck}
      action={
        warranty ? (
          <div className="flex">
            <IconButton icon={Pencil} label="Edit warranty" onClick={() => setEditing(true)} />
            <IconButton icon={Trash2} label="Remove warranty" tone="danger" onClick={() => setRemoving(true)} />
          </div>
        ) : (
          <Button variant="secondary" size="sm" icon={Plus} onClick={() => setEditing(true)}>
            Add warranty
          </Button>
        )
      }
    >
      {loading && data === undefined ? (
        <Skeleton className="h-20" />
      ) : !warranty ? (
        <p className="text-muted text-sm">No warranty recorded. Add one to be reminded before it runs out.</p>
      ) : (
        <div className="space-y-4">
          <div className="bg-surface-muted/70 rounded-xl p-4">
            <StatusBadge status={status} label={status === 'active' ? 'Active warranty' : undefined} />
            <p className="text-ink mt-2 font-semibold">{item.name}</p>
            {warranty.expiry_date && (
              <p className="text-muted mt-0.5 text-sm">
                {days !== null && days < 0 ? 'Warranty expired' : 'Warranty expires'}: {formatDate(warranty.expiry_date)}
                {days !== null && ` (${relativeDays(days)})`}
              </p>
            )}
          </div>
          <DetailList
            items={[
              { label: 'Warranty start', value: formatDate(warranty.start_date) },
              { label: 'Warranty expiry', value: formatDate(warranty.expiry_date) },
              { label: 'Warranty provider', value: warranty.provider },
              { label: 'Retailer', value: item.retailer },
              { label: 'Notes', value: warranty.notes, full: true },
            ]}
          />
          <p className="text-muted text-xs">Upload the warranty document below under “Documents & receipts”.</p>
        </div>
      )}

      <FormModal
        open={editing}
        onClose={() => setEditing(false)}
        title={warranty ? 'Edit warranty' : 'Add warranty'}
        size="md"
        fields={WARRANTY_ONLY_FIELDS}
        initial={toFormValues(WARRANTY_ONLY_FIELDS, warranty, {
          start_date: item.purchase_date ?? '',
          provider: item.brand ?? '',
        })}
        extraValidate={(v) =>
          v.start_date && v.expiry_date && v.expiry_date < v.start_date
            ? { expiry_date: 'Expiry must be after the start date.' }
            : {}
        }
        onSubmit={async (payload) => {
          setData(await saveWarranty(warranty, propertyId, cfg.warrantyKey, item.id, payload));
          toast.success('Warranty saved');
          setEditing(false);
        }}
      />
      <ConfirmDialog
        open={removing}
        onClose={() => setRemoving(false)}
        title="Remove warranty?"
        message="The warranty details will be removed. Any documents stay attached to the item."
        confirmLabel="Remove"
        onConfirm={async () => {
          if (!warranty) return;
          await deleteRow('warranties', warranty.id);
          setData(null);
          toast.success('Warranty removed');
        }}
      />
    </Section>
  );
}

function ApplianceTasks({ applianceId }: { applianceId: string }) {
  const { data, loading } = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('maintenance_tasks')
          .select('*')
          .eq('appliance_id', applianceId)
          .is('completed_at', null)
          .order('due_date')
          .limit(10),
      ) as MaintenanceTask[],
    [applianceId],
  );
  return (
    <Section
      title="Maintenance"
      icon={Wrench}
      action={
        <LinkButton to={`/maintenance?new=1&appliance=${applianceId}`} variant="secondary" size="sm" icon={Plus}>
          Add task
        </LinkButton>
      }
    >
      {loading && !data ? (
        <Skeleton className="h-14" />
      ) : !data?.length ? (
        <p className="text-muted text-sm">No upcoming maintenance for this appliance.</p>
      ) : (
        <ul className="space-y-2">
          {data.map((t) => (
            <li key={t.id}>
              <ListCard
                to={`/maintenance/${t.id}`}
                title={t.title}
                subtitle={`Due ${formatDate(t.due_date)}`}
                trailing={<StatusBadge status={taskStatus(t)} />}
              />
            </li>
          ))}
        </ul>
      )}
    </Section>
  );
}

export default function ItemDetail({ kind }: { kind: ItemKind }) {
  const cfg = ITEM_CONFIG[kind];
  const { id } = useParams();
  const property = useActiveProperty();
  const state = useRecord<Item>(cfg.table, id);
  const { data: rooms } = useRooms(property.id);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const navigate = useNavigate();
  const toast = useToast();

  return (
    <DetailScaffold state={state} backTo={cfg.path} backLabel={cfg.plural} propertyId={property.id}>
      {(item) => {
        const roomName = rooms?.find((r) => r.id === item.room_id)?.name;
        const inv = kind === 'inventory' ? (item as InventoryItem) : null;
        const app = kind === 'appliance' ? (item as Appliance) : null;
        return (
          <>
            <PageHeader
              back={{ to: cfg.path, label: cfg.plural }}
              title={item.name}
              description={[item.brand, item.model, roomName].filter(Boolean).join(' · ') || undefined}
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
                <Section title="Details" icon={Info}>
                  <DetailList
                    items={[
                      { label: 'Category', value: item.category },
                      { label: 'Room', value: roomName },
                      { label: 'Brand', value: item.brand },
                      { label: 'Model', value: item.model },
                      { label: 'Serial number', value: item.serial_number },
                      { label: 'Condition', value: app?.condition },
                      { label: 'Purchase date', value: formatDate(item.purchase_date) },
                      { label: 'Purchase price', value: formatMoney(item.purchase_price) },
                      { label: 'Current estimated value', value: formatMoney(inv?.current_value) },
                      { label: 'Retailer', value: item.retailer },
                      { label: 'Notes', value: item.notes, full: true },
                    ]}
                  />
                </Section>
                <WarrantyCard kind={kind} item={item} propertyId={property.id} />
                {kind === 'appliance' && <ApplianceTasks applianceId={item.id} />}
                <CustomFields propertyId={property.id} entityType={cfg.customEntity} entityId={item.id} />
              </div>
              <div className="space-y-4">
                <PhotoGallery propertyId={property.id} link={{ key: cfg.linkKey, id: item.id }} itemName={item.name} />
                <DocumentsPanel
                  propertyId={property.id}
                  link={{ key: cfg.linkKey, id: item.id }}
                  emptyText="Upload the receipt, manual or warranty document."
                />
              </div>
            </div>

            <ItemFormModal
              kind={kind}
              open={editing}
              onClose={() => setEditing(false)}
              propertyId={property.id}
              item={item}
              onSaved={(saved) => state.setData(saved)}
            />
            <ConfirmDialog
              open={deleting}
              onClose={() => setDeleting(false)}
              title={`Delete ${item.name}?`}
              message="This deletes the item, its warranty and photos. Its documents are kept in Documents."
              onConfirm={async () => {
                await deleteWithPhotos(cfg.table, item.id, cfg.linkKey);
                toast.success(`${item.name} deleted`);
                navigate(cfg.path, { replace: true });
              }}
            />
          </>
        );
      }}
    </DetailScaffold>
  );
}
