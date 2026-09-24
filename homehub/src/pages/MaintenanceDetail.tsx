import { Check, Info, Pencil, RotateCcw, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { DetailScaffold, useRecord } from '@/components/DetailScaffold';
import { DocumentsPanel } from '@/components/files/DocumentsPanel';
import { PhotoGallery } from '@/components/files/PhotoGallery';
import { StatusBadge } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { DetailList, PageHeader } from '@/components/ui/Layout';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useRooms } from '@/hooks/useData';
import { useQuery } from '@/hooks/useQuery';
import { deleteWithPhotos } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { formatDate } from '@/lib/format';
import { taskStatus } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { MaintenanceTask } from '@/lib/types';
import { recurrenceLabel, TaskFormModal, useCompleteTask } from './maintenance/shared';

export default function MaintenanceDetail() {
  const { id } = useParams();
  const property = useActiveProperty();
  const state = useRecord<MaintenanceTask>('maintenance_tasks', id);
  const { data: rooms } = useRooms(property.id);
  const applianceId = state.data?.appliance_id;
  const { data: appliance } = useQuery(
    async () =>
      unwrap(await supabase.from('appliances').select('id, name').eq('id', applianceId!).maybeSingle()) as {
        id: string;
        name: string;
      } | null,
    [applianceId],
    Boolean(applianceId),
  );
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const navigate = useNavigate();
  const toast = useToast();
  const { complete, reopen, busyId } = useCompleteTask(() => void state.reload());

  return (
    <DetailScaffold state={state} backTo="/maintenance" backLabel="Maintenance" propertyId={property.id}>
      {(task) => {
        const done = Boolean(task.completed_at);
        return (
          <>
            <PageHeader
              back={{ to: '/maintenance', label: 'Maintenance' }}
              title={task.title}
              description={<StatusBadge status={taskStatus(task)} />}
              actions={
                <>
                  {done ? (
                    <Button variant="secondary" icon={RotateCcw} loading={busyId === task.id} onClick={() => reopen(task)}>
                      Mark as not done
                    </Button>
                  ) : (
                    <Button icon={Check} loading={busyId === task.id} onClick={() => complete(task)}>
                      Mark as done
                    </Button>
                  )}
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
              <Section title="Details" icon={Info}>
                <DetailList
                  items={[
                    { label: 'Due date', value: formatDate(task.due_date) },
                    { label: 'Completed', value: task.completed_at ? formatDate(task.completed_at) : null },
                    { label: 'Repeats', value: recurrenceLabel(task) ?? 'Does not repeat' },
                    { label: 'Category', value: task.category },
                    { label: 'Room', value: rooms?.find((r) => r.id === task.room_id)?.name },
                    {
                      label: 'Appliance',
                      value: appliance ? (
                        <Link to={`/appliances/${appliance.id}`} className="text-brand-fg font-medium hover:underline">
                          {appliance.name}
                        </Link>
                      ) : null,
                    },
                    { label: 'Property', value: property.name },
                    { label: 'Description', value: task.description, full: true },
                    { label: 'Notes', value: task.notes, full: true },
                  ]}
                />
              </Section>
              <div className="space-y-4">
                <PhotoGallery propertyId={property.id} link={{ key: 'maintenance_task_id', id: task.id }} itemName={task.title} />
                <DocumentsPanel
                  propertyId={property.id}
                  link={{ key: 'maintenance_task_id', id: task.id }}
                  title="Documents"
                  defaultCategory="Maintenance"
                  emptyText="Upload certificates, invoices or instructions."
                />
              </div>
            </div>
            <TaskFormModal
              open={editing}
              onClose={() => setEditing(false)}
              propertyId={property.id}
              task={task}
              onSaved={(t) => state.setData(t)}
            />
            <ConfirmDialog
              open={deleting}
              onClose={() => setDeleting(false)}
              title={`Delete "${task.title}"?`}
              message="This deletes this task and its photos. Documents are kept in Documents."
              onConfirm={async () => {
                await deleteWithPhotos('maintenance_tasks', task.id, 'maintenance_task_id');
                toast.success('Task deleted');
                navigate('/maintenance', { replace: true });
              }}
            />
          </>
        );
      }}
    </DetailScaffold>
  );
}
