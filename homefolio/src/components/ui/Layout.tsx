import { ChevronLeft, Search } from 'lucide-react';
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { cn } from '@/lib/cn';
import { HelpButton } from '../help/HelpButton';
import { controlClass } from './Field';

interface PageHeaderProps {
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  back?: { to: string; label: string };
}

export function PageHeader({ title, description, actions, back }: PageHeaderProps) {
  return (
    <header className="mb-5 sm:mb-6">
      {back && (
        <Link
          to={back.to}
          className="text-muted hover:text-ink mb-2 -ml-1 inline-flex items-center gap-1 rounded-lg px-1 py-1 text-sm font-medium"
        >
          <ChevronLeft className="size-4" aria-hidden />
          {back.label}
        </Link>
      )}
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-ink text-2xl font-semibold tracking-tight sm:text-3xl">{title}</h1>
          {description && <div className="text-muted mt-1 text-sm sm:text-base">{description}</div>}
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <HelpButton />
          {actions && (
            <div className="flex flex-wrap gap-2" data-tour="page-actions">
              {actions}
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

interface ChipsProps<T extends string> {
  value: T;
  onChange: (value: T) => void;
  options: { value: T; label: string; count?: number }[];
  label: string;
}

/** Horizontally scrollable filter chips; works well on narrow screens. */
export function Chips<T extends string>({ value, onChange, options, label }: ChipsProps<T>) {
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className="-mx-4 flex scrollbar-none gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:px-0"
    >
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(o.value)}
            className={cn(
              'inline-flex min-h-9 shrink-0 items-center gap-1.5 rounded-full border px-3.5 text-sm font-medium transition-colors',
              selected ? 'border-brand-600 bg-brand-600 text-white' : 'border-line bg-surface text-ink hover:bg-surface-muted',
            )}
          >
            {o.label}
            {o.count !== undefined && <span className={cn('text-xs', selected ? 'text-white/80' : 'text-muted')}>{o.count}</span>}
          </button>
        );
      })}
    </div>
  );
}

export function SearchInput({
  value,
  onChange,
  placeholder = 'Search',
  label = 'Search',
  autoFocus,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  label?: string;
  autoFocus?: boolean;
}) {
  return (
    <div className="relative">
      <Search className="text-muted pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2" aria-hidden />
      <input
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={label}
        autoFocus={autoFocus}
        className={cn(controlClass, 'pl-10')}
      />
    </div>
  );
}

export interface DetailItem {
  label: string;
  value: ReactNode;
  full?: boolean;
}

/** Label/value pairs for detail pages. Empty values are skipped. */
export function DetailList({ items, empty = 'No details added yet.' }: { items: DetailItem[]; empty?: string }) {
  const visible = items.filter((i) => i.value !== null && i.value !== undefined && i.value !== '' && i.value !== false);
  if (!visible.length) return <p className="text-muted text-sm">{empty}</p>;
  return (
    <dl className="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
      {visible.map((i) => (
        <div key={i.label} className={cn('min-w-0', i.full && 'sm:col-span-2')}>
          <dt className="text-muted text-xs font-medium tracking-wide uppercase">{i.label}</dt>
          <dd className="text-ink mt-1 text-sm break-words whitespace-pre-line">{i.value}</dd>
        </div>
      ))}
    </dl>
  );
}

export function Grid({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3', className)}>{children}</div>;
}
