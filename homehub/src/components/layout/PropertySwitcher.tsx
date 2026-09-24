import { Check, ChevronsUpDown, Home, Settings2 } from 'lucide-react';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useProperties } from '@/context/PropertyContext';
import { cn } from '@/lib/cn';
import { propertyAddress } from '@/lib/format';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';

/** Shows the active property; tapping opens a list to switch between homes. */
export function PropertySwitcher({ compact }: { compact?: boolean }) {
  const { properties, active, setActive } = useProperties();
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();

  if (!active) return null;

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(
          'hover:bg-surface-muted flex min-w-0 items-center gap-2.5 rounded-xl text-left transition-colors',
          compact ? 'max-w-[60vw] px-2 py-1.5' : 'border-line bg-surface w-full border px-3 py-2.5',
        )}
        aria-label={`Current property: ${active.name}. Switch property`}
      >
        {!compact && (
          <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-9 shrink-0 items-center justify-center rounded-lg">
            <Home className="size-4.5" aria-hidden />
          </span>
        )}
        <span className="min-w-0 flex-1">
          <span className="text-ink block truncate text-sm font-semibold">{active.name}</span>
          {!compact && <span className="text-muted block truncate text-xs">{propertyAddress(active) || 'No address added'}</span>}
        </span>
        <ChevronsUpDown className="text-muted size-4 shrink-0" aria-hidden />
      </button>

      <Modal open={open} onClose={() => setOpen(false)} title="Switch property">
        <ul className="space-y-2" role="listbox" aria-label="Properties">
          {properties.map((p) => {
            const selected = p.id === active.id;
            return (
              <li key={p.id}>
                <button
                  type="button"
                  role="option"
                  aria-selected={selected}
                  onClick={() => {
                    setActive(p.id);
                    setOpen(false);
                  }}
                  className={cn(
                    'flex w-full items-center gap-3 rounded-xl border p-3 text-left transition-colors',
                    selected ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/30' : 'border-line hover:bg-surface-muted',
                  )}
                >
                  <Home className="text-brand-fg size-5 shrink-0" aria-hidden />
                  <span className="min-w-0 flex-1">
                    <span className="text-ink block truncate font-medium">{p.name}</span>
                    <span className="text-muted block truncate text-sm">{propertyAddress(p) || 'No address added'}</span>
                  </span>
                  {selected && <Check className="text-brand-fg size-5" aria-label="Selected" />}
                </button>
              </li>
            );
          })}
        </ul>
        <Button
          variant="secondary"
          icon={Settings2}
          className="mt-4 w-full"
          onClick={() => {
            setOpen(false);
            navigate('/properties');
          }}
        >
          Manage properties
        </Button>
      </Modal>
    </>
  );
}
