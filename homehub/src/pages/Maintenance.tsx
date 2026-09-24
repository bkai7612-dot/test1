import { CalendarCheck, Plus, Wrench } from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { StatusBadge, Tag } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { Chips, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useActiveProperty } from '@/context/PropertyContext';
import { useRooms } from '@/hooks/useData';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { unwrap } from '@/lib/errors';
import { daysUntil, formatDate, relativeDays } from '@/lib/format';
import { taskStatus, type Status } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { MaintenanceTask } from '@/lib/types';
import { CompleteButton, RecurrenceTag, TaskFormModal, useCompleteTask } from './maintenance/shared';

type Tab = 'open' | 'overdue' | 'due' | 'upcoming' | 'completed';
const COMPLETED_PAGE = 20;

function dueText(t: MaintenanceTask): string {
  if (t.completed_at) return `Completed ${formatDate(t.completed_at)}`;
  const days = daysUntil(t.due_date);
  if (days < 0) return `Overdue by ${relativeDays(days).replace(' ago', '')} · ${formatDate(t.due_date, 'short')}`;
  if (days === 0) return 'Due today';
  return `Due ${relativeDays(days)} · ${formatDate(t.due_date, 'short')}`;
}

function TaskRow({
  task,
  roomName,
  onToggle,
  busy,
}: {
  task: MaintenanceTask;
  roomName?: string;
  onToggle: () => void;
  busy: boolean;
}) {
  const status = taskStatus(task);
  return (
    <li className="border-line bg-surface flex items-center gap-3 rounded-2xl border p-3 sm:p-4">
      <CompleteButton task={task} onClick={onToggle} busy={busy} />
      <Link to={`/maintenance/${task.id}`} className="min-w-0 flex-1 rounded-lg">
        <span className={`block truncate font-medium ${task.completed_at ? 'text-muted line-through' : 'text-ink'}`}>
          {task.title}
        </span>
        <span className="text-muted mt-0.5 block truncate text-sm">{dueText(task)}</span>
        <span className="mt-2 flex flex-wrap gap-2">
          <StatusBadge status={status} />
          <RecurrenceTag task={task} />
          {roomName && <Tag>{roomName}</Tag>}
        </span>
      </Link>
    </li>
  );
}

export default function Maintenance() {
  const property = useActiveProperty();
  const editor = useEditor<MaintenanceTask>();
  const [params] = useSearchParams();
  const [defaults] = useState(() => ({ appliance_id: params.get('appliance'), room_id: params.get('room') }));
  const [tab, setTab] = useState<Tab>('open');
  const [completedLimit, setCompletedLimit] = useState(COMPLETED_PAGE);
  const { data: rooms } = useRooms(property.id);
  const roomName = useMemo(() => new Map((rooms ?? []).map((r) => [r.id, r.name])), [rooms]);

  const open = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('maintenance_tasks')
          .select('*')
          .eq('property_id', property.id)
          .is('completed_at', null)
          .order('due_date'),
      ) as MaintenanceTask[],
    [property.id],
  );
  const completed = useQuery(
    async () =>
      unwrap(
        await supabase
          .from('maintenance_tasks')
          .select('*')
          .eq('property_id', property.id)
          .not('completed_at', 'is', null)
          .order('completed_at', { ascending: false })
          .limit(completedLimit + 1),
      ) as MaintenanceTask[],
    [property.id, completedLimit],
  );

  const reloadAll = () => {
    void open.reload();
    void completed.reload();
  };
  const { complete, reopen, busyId } = useCompleteTask(reloadAll);

  const grouped = useMemo(() => {
    const g: Record<Exclude<Status, 'active' | 'expiring' | 'expired' | 'completed' | 'none'>, MaintenanceTask[]> = {
      overdue: [],
      due: [],
      upcoming: [],
    };
    for (const t of open.data ?? []) g[taskStatus(t) as 'overdue' | 'due' | 'upcoming'].push(t);
    return g;
  }, [open.data]);

  const completedRows = (completed.data ?? []).slice(0, completedLimit);

  const addButton = (
    <Button icon={Plus} onClick={editor.openNew}>
      Add task
    </Button>
  );

  const renderList = (tasks: MaintenanceTask[]) => (
    <ul className="space-y-2">
      {tasks.map((t) => (
        <TaskRow
          key={t.id}
          task={t}
          roomName={t.room_id ? roomName.get(t.room_id) : undefined}
          busy={busyId === t.id}
          onToggle={() => (t.completed_at ? reopen(t) : complete(t))}
        />
      ))}
    </ul>
  );

  const sections: { key: 'overdue' | 'due' | 'upcoming'; title: string }[] = [
    { key: 'overdue', title: 'Overdue' },
    { key: 'due', title: 'Due today' },
    { key: 'upcoming', title: 'Upcoming' },
  ];

  const loading = open.loading && !open.data;
  const nothingAtAll = !loading && !open.data?.length && !completed.data?.length;

  return (
    <>
      <PageHeader title="Maintenance" description="Simple reminders to keep your home in good shape." actions={addButton} />
      {loading ? (
        <ListSkeleton />
      ) : open.error ? (
        <ErrorState error={open.error} onRetry={reloadAll} />
      ) : nothingAtAll ? (
        <EmptyState
          icon={Wrench}
          title="No maintenance tasks yet"
          description="Add reminders like “Boiler service” or “Check smoke alarms”. Repeating tasks schedule themselves when you tick them off."
          action={addButton}
        />
      ) : (
        <>
          <div className="mb-5">
            <Chips
              label="Filter tasks"
              value={tab}
              onChange={setTab}
              options={[
                { value: 'open', label: 'To do', count: open.data?.length ?? 0 },
                { value: 'overdue', label: 'Overdue', count: grouped.overdue.length },
                { value: 'due', label: 'Due today', count: grouped.due.length },
                { value: 'upcoming', label: 'Upcoming', count: grouped.upcoming.length },
                { value: 'completed', label: 'Completed' },
              ]}
            />
          </div>

          {tab === 'open' &&
            (open.data?.length ? (
              <div className="space-y-6">
                {sections
                  .filter((s) => grouped[s.key].length)
                  .map((s) => (
                    <section key={s.key} aria-labelledby={`h-${s.key}`}>
                      <h2 id={`h-${s.key}`} className="text-muted mb-2 text-sm font-semibold tracking-wide uppercase">
                        {s.title} <span className="font-normal">({grouped[s.key].length})</span>
                      </h2>
                      {renderList(grouped[s.key])}
                    </section>
                  ))}
              </div>
            ) : (
              <EmptyState
                icon={CalendarCheck}
                title="All caught up"
                description="There's nothing left to do. Nice work!"
                action={addButton}
              />
            ))}

          {(tab === 'overdue' || tab === 'due' || tab === 'upcoming') &&
            (grouped[tab].length ? (
              renderList(grouped[tab])
            ) : (
              <EmptyState compact icon={CalendarCheck} title="Nothing here" description="No tasks in this group right now." />
            ))}

          {tab === 'completed' &&
            (completed.loading && !completed.data ? (
              <ListSkeleton rows={3} />
            ) : completedRows.length ? (
              <>
                {renderList(completedRows)}
                {(completed.data?.length ?? 0) > completedLimit && (
                  <Button
                    variant="secondary"
                    className="mt-4 w-full"
                    onClick={() => setCompletedLimit((l) => l + COMPLETED_PAGE)}
                  >
                    Show more
                  </Button>
                )}
              </>
            ) : (
              <EmptyState
                compact
                icon={CalendarCheck}
                title="Nothing completed yet"
                description="Tasks you tick off will be listed here with the date you completed them."
              />
            ))}
        </>
      )}
      <TaskFormModal
        open={editor.isOpen}
        onClose={editor.close}
        propertyId={property.id}
        task={editor.row}
        defaults={defaults}
        onSaved={reloadAll}
      />
    </>
  );
}
