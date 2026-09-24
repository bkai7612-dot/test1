import { ChevronRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import { MORE_ITEMS } from '@/components/layout/nav';
import { PageHeader } from '@/components/ui/Layout';

/** Mobile overflow menu for sections not in the bottom bar. */
export default function More() {
  return (
    <>
      <PageHeader title="More" />
      <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {MORE_ITEMS.map(({ to, label, icon: Icon, description }) => (
          <li key={to}>
            <Link
              to={to}
              className="border-line bg-surface hover:border-brand-300 flex min-h-16 items-center gap-3 rounded-2xl border p-3 transition-colors"
            >
              <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-11 shrink-0 items-center justify-center rounded-xl">
                <Icon className="size-5" aria-hidden />
              </span>
              <span className="min-w-0 flex-1">
                <span className="text-ink block font-medium">{label}</span>
                {description && <span className="text-muted block truncate text-sm">{description}</span>}
              </span>
              <ChevronRight className="text-muted size-4" aria-hidden />
            </Link>
          </li>
        ))}
      </ul>
    </>
  );
}
