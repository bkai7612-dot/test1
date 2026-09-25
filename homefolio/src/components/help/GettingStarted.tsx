import { ArrowRight, Check, ListChecks, X } from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@/hooks/useQuery';
import { cn } from '@/lib/cn';
import { supabase } from '@/lib/supabase';
import { Card } from '../ui/Card';

const STEPS: { table: string | null; label: string; hint: string; to: string }[] = [
  { table: null, label: 'Add your home', hint: 'Done — nice start.', to: '/properties' },
  { table: 'rooms', label: 'Add a room', hint: 'So you know what is where.', to: '/rooms?new=1' },
  { table: 'appliances', label: 'Add an appliance', hint: 'Start with the boiler or washing machine.', to: '/appliances?new=1' },
  { table: 'documents', label: 'Upload a receipt or document', hint: 'Snap a photo of a paper receipt.', to: '/documents?new=1' },
  {
    table: 'maintenance_tasks',
    label: 'Set a maintenance reminder',
    hint: 'For example "Boiler service", yearly.',
    to: '/maintenance?new=1',
  },
  {
    table: 'insurance_policies',
    label: 'Add your home insurance',
    hint: 'Get reminded before it renews.',
    to: '/insurance?new=1',
  },
  {
    table: 'emergency_contacts',
    label: 'Add an emergency contact',
    hint: 'Your plumber, electrician or landlord.',
    to: '/emergency?new=1',
  },
];

const hiddenKey = (propertyId: string) => `homefolio-checklist-hidden:${propertyId}`;

function readHidden(propertyId: string): boolean {
  try {
    return localStorage.getItem(hiddenKey(propertyId)) === '1';
  } catch {
    return false;
  }
}

/** First-steps checklist on the Home screen. Ticks itself off as things are added; hides when complete. */
export function GettingStarted({ propertyId }: { propertyId: string }) {
  const [hidden, setHidden] = useState(() => readHidden(propertyId));
  const { data } = useQuery(
    async () =>
      Promise.all(
        STEPS.map(async (s) => {
          if (!s.table) return true;
          const { count } = await supabase
            .from(s.table)
            .select('id', { count: 'exact', head: true })
            .eq('property_id', propertyId);
          return (count ?? 0) > 0;
        }),
      ),
    [propertyId],
  );

  if (!data || hidden || readHidden(propertyId)) return null;
  const done = data.filter(Boolean).length;
  if (done === STEPS.length) return null;

  const hide = () => {
    try {
      localStorage.setItem(hiddenKey(propertyId), '1');
    } catch {
      // Private browsing: it simply hides until the next visit.
    }
    setHidden(true);
  };
  const next = data.findIndex((d) => !d);

  return (
    <Card className="p-4 sm:p-5" data-tour="checklist">
      <div className="mb-3 flex items-start justify-between gap-3">
        <div>
          <h2 className="text-ink flex items-center gap-2 text-base font-semibold">
            <ListChecks className="text-brand-fg size-5" aria-hidden />
            Getting started
          </h2>
          <p className="text-muted mt-0.5 text-sm">
            {done} of {STEPS.length} done — follow these to set up your home.
          </p>
        </div>
        <button
          type="button"
          onClick={hide}
          aria-label="Hide the getting started checklist"
          className="text-muted hover:bg-surface-muted hover:text-ink -mt-1 -mr-2 inline-flex size-10 shrink-0 items-center justify-center rounded-xl"
        >
          <X className="size-5" aria-hidden />
        </button>
      </div>
      <div className="bg-surface-muted mb-3 h-2 overflow-hidden rounded-full" aria-hidden>
        <div className="bg-brand-600 h-full rounded-full transition-all" style={{ width: `${(100 * done) / STEPS.length}%` }} />
      </div>
      <ol className="divide-line -mx-2 divide-y">
        {STEPS.map((s, i) => {
          const complete = data[i];
          return (
            <li key={s.label}>
              <Link
                to={s.to}
                className={cn(
                  'hover:bg-surface-muted/60 flex items-center gap-3 rounded-xl px-2 py-2.5',
                  i === next && 'bg-brand-50/60 dark:bg-brand-900/20',
                )}
              >
                <span
                  className={cn(
                    'flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold',
                    complete ? 'bg-brand-600 text-white' : 'border-line text-muted border',
                  )}
                >
                  {complete ? <Check className="size-4" aria-label="Done" /> : i + 1}
                </span>
                <span className="min-w-0 flex-1">
                  <span className={cn('block text-sm font-medium', complete ? 'text-muted line-through' : 'text-ink')}>
                    {s.label}
                  </span>
                  {!complete && <span className="text-muted block text-xs">{s.hint}</span>}
                </span>
                {!complete && <ArrowRight className="text-muted size-4 shrink-0" aria-hidden />}
              </Link>
            </li>
          );
        })}
      </ol>
    </Card>
  );
}
