import type { LucideIcon } from 'lucide-react';
import type { HTMLAttributes, ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { cn } from '@/lib/cn';

export function Card({ className, ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('border-line bg-surface rounded-2xl border', className)} {...rest} />;
}

interface SectionProps {
  title: string;
  icon?: LucideIcon;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
  description?: string;
}

/** A titled card section, used on detail pages and the dashboard. */
export function Section({ title, icon: Icon, action, children, className, description }: SectionProps) {
  return (
    <Card className={cn('p-4 sm:p-5', className)}>
      <div className="mb-3 flex items-center justify-between gap-3">
        <div className="min-w-0">
          <h2 className="text-ink flex items-center gap-2 text-base font-semibold">
            {Icon && <Icon className="text-brand-fg size-5" aria-hidden />}
            {title}
          </h2>
          {description && <p className="text-muted mt-0.5 text-sm">{description}</p>}
        </div>
        {action}
      </div>
      {children}
    </Card>
  );
}

interface ListCardProps {
  to?: string;
  onClick?: () => void;
  icon?: LucideIcon;
  title: ReactNode;
  subtitle?: ReactNode;
  meta?: ReactNode;
  trailing?: ReactNode;
  className?: string;
}

/** A tappable card row used in every list view. */
export function ListCard({ to, onClick, icon: Icon, title, subtitle, meta, trailing, className }: ListCardProps) {
  const inner = (
    <>
      {Icon && (
        <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-11 shrink-0 items-center justify-center rounded-xl">
          <Icon className="size-5" aria-hidden />
        </span>
      )}
      <span className="min-w-0 flex-1">
        <span className="text-ink block truncate font-medium">{title}</span>
        {subtitle && <span className="text-muted mt-0.5 block truncate text-sm">{subtitle}</span>}
        {meta && <span className="mt-2 flex flex-wrap gap-2">{meta}</span>}
      </span>
      {trailing}
    </>
  );
  const cls = cn(
    'flex w-full items-center gap-3 rounded-2xl border border-line bg-surface p-3 text-left sm:p-4',
    (to || onClick) && 'transition-colors hover:border-brand-300 hover:bg-surface-muted/50',
    className,
  );
  if (to)
    return (
      <Link to={to} className={cls}>
        {inner}
      </Link>
    );
  if (onClick)
    return (
      <button type="button" onClick={onClick} className={cls}>
        {inner}
      </button>
    );
  return <div className={cls}>{inner}</div>;
}
