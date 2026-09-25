import {
  AlertCircle,
  CalendarClock,
  CheckCircle2,
  Clock,
  ShieldCheck,
  ShieldOff,
  CircleDot,
  type LucideIcon,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { cn } from '@/lib/cn';
import type { Status } from '@/lib/status';

const STATUS_STYLES: Record<Status, { label: string; icon: LucideIcon; className: string }> = {
  active: {
    label: 'Active',
    icon: ShieldCheck,
    className:
      'bg-emerald-50 text-emerald-800 ring-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-300 dark:ring-emerald-900',
  },
  expiring: {
    label: 'Expiring soon',
    icon: Clock,
    className: 'bg-amber-50 text-amber-800 ring-amber-200 dark:bg-amber-950/40 dark:text-amber-300 dark:ring-amber-900',
  },
  expired: {
    label: 'Expired',
    icon: ShieldOff,
    className: 'bg-stone-100 text-stone-700 ring-stone-200 dark:bg-stone-800/60 dark:text-stone-300 dark:ring-stone-700',
  },
  upcoming: {
    label: 'Upcoming',
    icon: CalendarClock,
    className: 'bg-sky-50 text-sky-800 ring-sky-200 dark:bg-sky-950/40 dark:text-sky-300 dark:ring-sky-900',
  },
  due: {
    label: 'Due',
    icon: Clock,
    className: 'bg-amber-50 text-amber-800 ring-amber-200 dark:bg-amber-950/40 dark:text-amber-300 dark:ring-amber-900',
  },
  overdue: {
    label: 'Overdue',
    icon: AlertCircle,
    className: 'bg-rose-50 text-rose-800 ring-rose-200 dark:bg-rose-950/40 dark:text-rose-300 dark:ring-rose-900',
  },
  completed: {
    label: 'Completed',
    icon: CheckCircle2,
    className:
      'bg-emerald-50 text-emerald-800 ring-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-300 dark:ring-emerald-900',
  },
  none: {
    label: 'No date',
    icon: CircleDot,
    className: 'bg-stone-100 text-stone-700 ring-stone-200 dark:bg-stone-800/60 dark:text-stone-300 dark:ring-stone-700',
  },
};

/** Status is always conveyed with an icon and text, not colour alone. */
export function StatusBadge({ status, label }: { status: Status; label?: string }) {
  const s = STATUS_STYLES[status];
  const Icon = s.icon;
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap ring-1 ring-inset',
        s.className,
      )}
    >
      <Icon className="size-3.5" aria-hidden />
      {label ?? s.label}
    </span>
  );
}

export function Tag({ children, icon: Icon }: { children: ReactNode; icon?: LucideIcon }) {
  return (
    <span className="bg-surface-muted text-muted inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium whitespace-nowrap">
      {Icon && <Icon className="size-3.5" aria-hidden />}
      {children}
    </span>
  );
}
