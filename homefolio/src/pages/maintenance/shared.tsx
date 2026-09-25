import { Check, Repeat } from 'lucide-react';
import { useState } from 'react';
import { FormModal, toFormValues, type FieldDef } from '@/components/forms/EntityForm';
import { useToast } from '@/context/ToastContext';
import { useRooms } from '@/hooks/useData';
import { useQuery } from '@/hooks/useQuery';
import { insertRow, updateRow } from '@/lib/api';
import { RECURRENCE_OPTIONS, RECURRENCE_UNITS } from '@/lib/constants';
import { unwrap } from '@/lib/errors';
import { MAINTENANCE_FIELDS } from '@/lib/fields';
import { formatDate, labelFor, todayISO } from '@/lib/format';
import { cn } from '@/lib/cn';
import { supabase } from '@/lib/supabase';
import type { MaintenanceTask } from '@/lib/types';

export function recurrenceLabel(
  t: Pick<MaintenanceTask, 'recurrence' | 'recurrence_interval' | 'recurrence_unit'>,
): string | null {
  if (t.recurrence === 'none') return null;
  if (t.recurrence === 'custom' && t.recurrence_interval && t.recurrence_unit) {
    const unit = labelFor(RECURRENCE_UNITS, t.recurrence_unit).toLowerCase();
    return t.recurrence_interval === 1 ? `Every ${unit.replace(/s$/, '')}` : `Every ${t.recurrence_interval} ${unit}`;
  }
  return labelFor(RECURRENCE_OPTIONS, t.recurrence);
}

export function RecurrenceTag({ task }: { task: MaintenanceTask }) {
  const label = recurrenceLabel(task);
  if (!label) return null;
  return (
    <span className="bg-surface-muted text-muted inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium">
      <Repeat className="size-3.5" aria-hidden />
      {label}
    </span>
  );
}

/** Completes a task; recurring tasks get their next occurrence created by the database. */
export function useCompleteTask(onDone: () => void) {
  const toast = useToast();
  const [busyId, setBusyId] = useState<string | null>(null);

  const complete = async (task: MaintenanceTask) => {
    setBusyId(task.id);
    try {
      const nextId = unwrap(await supabase.rpc('complete_maintenance_task', { p_task_id: task.id })) as string | null;
      if (nextId) {
        const next = unwrap(await supabase.from('maintenance_tasks').select('due_date').eq('id', nextId).single()) as {
          due_date: string;
        };
        toast.success(`Done! Next "${task.title}" is due ${formatDate(next.due_date)}.`);
      } else {
        toast.success(`"${task.title}" marked as done`);
      }
      onDone();
    } catch (err) {
      toast.error(err);
    } finally {
      setBusyId(null);
    }
  };

  const reopen = async (task: MaintenanceTask) => {
    setBusyId(task.id);
    try {
      unwrap(await supabase.rpc('reopen_maintenance_task', { p_task_id: task.id }));
      toast.success(`"${task.title}" moved back to your to-do list`);
      onDone();
    } catch (err) {
      toast.error(err);
    } finally {
      setBusyId(null);
    }
  };

  return { complete, reopen, busyId };
}

export function CompleteButton({ task, onClick, busy }: { task: MaintenanceTask; onClick: () => void; busy: boolean }) {
  const done = Boolean(task.completed_at);
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={busy}
      aria-label={done ? `Mark "${task.title}" as not done` : `Mark "${task.title}" as done`}
      aria-pressed={done}
      className={cn(
        'flex size-11 shrink-0 items-center justify-center rounded-full border-2 transition-colors disabled:opacity-50',
        done
          ? 'border-emerald-600 bg-emerald-600 text-white'
          : 'border-line text-transparent hover:border-emerald-500 hover:text-emerald-500',
        busy && 'animate-pulse',
      )}
    >
      <Check className="size-5" strokeWidth={3} aria-hidden />
    </button>
  );
}

interface TaskFormModalProps {
  open: boolean;
  onClose: () => void;
  propertyId: string;
  task?: MaintenanceTask | null;
  defaults?: { appliance_id?: string | null; room_id?: string | null };
  onSaved: (task: MaintenanceTask) => void;
}

export function TaskFormModal({ open, onClose, propertyId, task, defaults, onSaved }: TaskFormModalProps) {
  const toast = useToast();
  const { data: rooms } = useRooms(propertyId);
  const { data: appliances } = useQuery(
    async () =>
      unwrap(await supabase.from('appliances').select('id, name').eq('property_id', propertyId).order('name')) as {
        id: string;
        name: string;
      }[],
    [propertyId],
    open,
  );

  const fields: FieldDef[] = [
    ...MAINTENANCE_FIELDS.slice(0, 7),
    {
      name: 'appliance_id',
      label: 'Appliance',
      type: 'select',
      half: true,
      placeholder: appliances?.length ? 'None' : 'No appliances added',
      options: (appliances ?? []).map((a) => ({ value: a.id, label: a.name })),
    },
    ...MAINTENANCE_FIELDS.slice(7),
  ];

  return (
    <FormModal
      open={open}
      onClose={onClose}
      title={task ? 'Edit task' : 'Add maintenance task'}
      description={task ? undefined : 'Create a reminder for anything that needs doing.'}
      fields={fields}
      rooms={rooms}
      initial={toFormValues(fields, task, {
        due_date: todayISO(),
        recurrence: 'none',
        recurrence_unit: 'month',
        recurrence_interval: '1',
        appliance_id: defaults?.appliance_id ?? '',
        room_id: defaults?.room_id ?? '',
      })}
      onSubmit={async (payload) => {
        const saved = task
          ? await updateRow<MaintenanceTask>('maintenance_tasks', task.id, payload)
          : await insertRow<MaintenanceTask>('maintenance_tasks', { ...payload, property_id: propertyId });
        toast.success(task ? 'Task updated' : 'Task added');
        onSaved(saved);
        onClose();
      }}
    />
  );
}
