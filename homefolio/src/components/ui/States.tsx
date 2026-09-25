import { AlertTriangle, Loader2, RefreshCw, type LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { friendlyError } from '@/lib/errors';
import { cn } from '@/lib/cn';
import { Button } from './Button';

interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  description?: string;
  action?: ReactNode;
  compact?: boolean;
}

export function EmptyState({ icon: Icon, title, description, action, compact }: EmptyStateProps) {
  return (
    <div
      className={cn(
        'border-line flex flex-col items-center rounded-2xl border border-dashed text-center',
        compact ? 'px-4 py-6' : 'bg-surface px-6 py-12',
      )}
    >
      <span
        className={cn(
          'bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex items-center justify-center rounded-2xl',
          compact ? 'size-10' : 'size-14',
        )}
      >
        <Icon className={compact ? 'size-5' : 'size-7'} aria-hidden />
      </span>
      <h3 className={cn('text-ink font-semibold', compact ? 'mt-3 text-sm' : 'mt-4 text-lg')}>{title}</h3>
      {description && <p className="text-muted mt-1 max-w-sm text-sm">{description}</p>}
      {action && <div className={compact ? 'mt-3' : 'mt-5'}>{action}</div>}
    </div>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  return (
    <div role="alert" className="border-line bg-surface flex flex-col items-center rounded-2xl border px-6 py-10 text-center">
      <span className="flex size-12 items-center justify-center rounded-2xl bg-amber-50 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300">
        <AlertTriangle className="size-6" aria-hidden />
      </span>
      <h3 className="text-ink mt-4 font-semibold">We couldn't load this</h3>
      <p className="text-muted mt-1 max-w-sm text-sm">{friendlyError(error)}</p>
      {onRetry && (
        <Button variant="secondary" icon={RefreshCw} className="mt-5" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn('bg-surface-muted animate-pulse rounded-xl', className)} aria-hidden />;
}

export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="space-y-3" role="status" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="border-line bg-surface flex items-center gap-3 rounded-2xl border p-4">
          <Skeleton className="size-11" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-1/2" />
            <Skeleton className="h-3 w-1/3" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function Spinner({ label = 'Loading' }: { label?: string }) {
  return (
    <div role="status" className="text-muted flex items-center justify-center p-10">
      <Loader2 className="size-6 animate-spin" aria-hidden />
      <span className="sr-only">{label}</span>
    </div>
  );
}

export function FormError({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p role="alert" className="rounded-xl bg-rose-50 px-3.5 py-2.5 text-sm text-rose-700 dark:bg-rose-950/40 dark:text-rose-300">
      {message}
    </p>
  );
}
