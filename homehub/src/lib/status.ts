import { daysUntil } from './format';
import type { MaintenanceTask } from './types';

export type Status = 'active' | 'expiring' | 'expired' | 'upcoming' | 'due' | 'overdue' | 'completed' | 'none';

export const EXPIRING_SOON_DAYS = 60;

export function warrantyStatus(expiry: string | null | undefined): Status {
  if (!expiry) return 'none';
  const days = daysUntil(expiry);
  if (days < 0) return 'expired';
  if (days <= EXPIRING_SOON_DAYS) return 'expiring';
  return 'active';
}

export function taskStatus(task: Pick<MaintenanceTask, 'completed_at' | 'due_date'>): Status {
  if (task.completed_at) return 'completed';
  const days = daysUntil(task.due_date);
  if (days < 0) return 'overdue';
  if (days === 0) return 'due';
  return 'upcoming';
}

/** For renewal/contract dates: due soon behaves like "expiring". */
export function renewalStatus(date: string | null | undefined, soonDays = 30): Status {
  if (!date) return 'none';
  const days = daysUntil(date);
  if (days < 0) return 'expired';
  if (days <= soonDays) return 'due';
  return 'active';
}
