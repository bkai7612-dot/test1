/**
 * Phone reminders (iPhone and Android only). Reads the same "upcoming" list as
 * the dashboard and schedules local notifications at 9am:
 *   - maintenance tasks on the day they're due
 *   - warranty expiries, insurance renewals and contract ends 14 days before
 * Everything is rescheduled from scratch each time, so edits and completions
 * are always reflected. Nothing is sent to a server.
 */
import { formatDate, parseDate } from './format';
import { isNative } from './platform';
import { supabase } from './supabase';
import type { Profile, Reminder, ReminderKind } from './types';

const LOOK_AHEAD_DAYS = 60;
const MAX_SCHEDULED = 60; // iOS keeps at most 64 pending notifications per app.

function idFor(r: Reminder): number {
  const key = `${r.kind}:${r.item_id}:${r.due_date}`;
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (Math.imul(31, h) + key.charCodeAt(i)) | 0;
  return Math.abs(h) % 2_000_000_000;
}

function pathFor(r: Reminder): string {
  switch (r.kind) {
    case 'maintenance':
      return `/maintenance/${r.item_id}`;
    case 'warranty':
      return r.detail === 'inventory' ? `/inventory/${r.item_id}` : `/appliances/${r.item_id}`;
    case 'insurance':
      return `/insurance/${r.item_id}`;
    case 'contract':
      return `/utilities/${r.item_id}`;
  }
}

function textFor(r: Reminder, propertyName: string, multipleProperties: boolean): { title: string; body: string; at: Date } {
  const due = parseDate(r.due_date);
  const where = multipleProperties ? ` · ${propertyName}` : '';
  if (r.kind === 'maintenance') {
    const at = new Date(due.getFullYear(), due.getMonth(), due.getDate(), 9);
    return { title: `Due today: ${r.title}`, body: `Tap to see the details and mark it done${where}.`, at };
  }
  const at = new Date(due.getFullYear(), due.getMonth(), due.getDate() - 14, 9);
  const verb = r.kind === 'warranty' ? 'expires' : r.kind === 'insurance' ? 'renews' : 'ends';
  return { title: `${r.title} ${verb} in 2 weeks`, body: `On ${formatDate(r.due_date)}${where}.`, at };
}

const ENABLED: Record<ReminderKind, keyof Profile> = {
  maintenance: 'remind_maintenance',
  warranty: 'remind_warranties',
  insurance: 'remind_insurance',
  contract: 'remind_contracts',
};

export async function scheduleReminders(profile: Profile): Promise<void> {
  if (!isNative) return;
  const { LocalNotifications } = await import('@capacitor/local-notifications');

  let permission = await LocalNotifications.checkPermissions();
  if (permission.display === 'prompt' || permission.display === 'prompt-with-rationale') {
    permission = await LocalNotifications.requestPermissions();
  }
  if (permission.display !== 'granted') return;

  const { data: properties } = await supabase.from('properties').select('id, name');
  const list = (properties ?? []) as { id: string; name: string }[];
  const now = Date.now();
  const notifications: {
    id: number;
    title: string;
    body: string;
    schedule: { at: Date; allowWhileIdle: boolean };
    extra: { path: string; propertyId: string };
    isExactNotification: boolean;
  }[] = [];

  for (const property of list) {
    const { data } = await supabase.rpc('upcoming_reminders', { p_property_id: property.id, p_days: LOOK_AHEAD_DAYS });
    for (const r of (data ?? []) as Reminder[]) {
      if (!profile[ENABLED[r.kind]]) continue;
      const { title, body, at } = textFor(r, property.name, list.length > 1);
      if (at.getTime() <= now) continue;
      notifications.push({
        id: idFor(r),
        title,
        body,
        schedule: { at, allowWhileIdle: true },
        extra: { path: pathFor(r), propertyId: property.id },
        isExactNotification: false,
      });
    }
  }

  notifications.sort((a, b) => a.schedule.at.getTime() - b.schedule.at.getTime());
  const pending = await LocalNotifications.getPending();
  if (pending.notifications.length) {
    await LocalNotifications.cancel({ notifications: pending.notifications.map((n) => ({ id: n.id })) });
  }
  if (notifications.length) {
    await LocalNotifications.schedule({ notifications: notifications.slice(0, MAX_SCHEDULED) });
  }
}
