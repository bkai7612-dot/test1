/**
 * Prototype-only controls (never in the real apps): a note on the sign-in
 * screens and a small "Prototype" menu for testers.
 */
import { FlaskConical, RotateCcw, Compass, House, X } from 'lucide-react';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTour } from '@/components/help/Tour';
import { Button } from '@/components/ui/Button';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { useAuth } from '@/context/AuthContext';
import { exploreExampleHome, resetPrototype } from './supabase';

export function DemoAuthNotice() {
  const [busy, setBusy] = useState(false);
  return (
    <div className="border-brand-200 bg-brand-50 dark:border-brand-800 dark:bg-brand-900/30 mb-5 rounded-2xl border p-4 text-sm">
      <p className="text-ink flex items-center gap-2 font-semibold">
        <FlaskConical className="text-brand-fg size-4" aria-hidden />
        You are trying the Homefolio prototype
      </p>
      <p className="text-muted mt-1">
        Create an account with any email address — nothing is sent anywhere. What you add is saved in this browser only.
      </p>
      <Button
        variant="secondary"
        size="sm"
        className="mt-3 w-full"
        icon={House}
        loading={busy}
        onClick={() => {
          setBusy(true);
          void exploreExampleHome();
        }}
      >
        Or explore an example home
      </Button>
    </div>
  );
}

export default function DemoMenu() {
  const { session } = useAuth();
  const { start } = useTour();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [confirm, setConfirm] = useState<'example' | 'reset' | null>(null);
  if (!session) return null;

  return (
    <div className="fixed right-3 bottom-[calc(4.75rem+env(safe-area-inset-bottom))] z-40 flex flex-col items-end gap-2 lg:right-5 lg:bottom-5">
      {open && (
        <div className="border-line bg-surface w-72 rounded-2xl border p-3 shadow-xl" role="menu" aria-label="Prototype">
          <p className="text-muted px-2 pb-2 text-xs">
            This is a prototype. Everything works, but it is saved in this browser only and payments are switched off.
          </p>
          {[
            { label: 'Replay the tour', icon: Compass, onClick: () => start() },
            { label: 'Load the example home', icon: House, onClick: () => setConfirm('example') },
            { label: 'Start again as a new user', icon: RotateCcw, onClick: () => setConfirm('reset') },
          ].map(({ label, icon: Icon, onClick }) => (
            <button
              key={label}
              type="button"
              role="menuitem"
              onClick={() => {
                setOpen(false);
                onClick();
              }}
              className="text-ink hover:bg-surface-muted flex min-h-11 w-full items-center gap-3 rounded-xl px-2 text-left text-sm font-medium"
            >
              <Icon className="text-muted size-4" aria-hidden />
              {label}
            </button>
          ))}
        </div>
      )}
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="bg-ink text-canvas flex min-h-10 items-center gap-2 rounded-full px-4 text-sm font-medium shadow-lg"
      >
        {open ? <X className="size-4" aria-hidden /> : <FlaskConical className="size-4" aria-hidden />}
        Prototype
      </button>
      <ConfirmDialog
        open={confirm === 'example'}
        onClose={() => setConfirm(null)}
        title="Load the example home?"
        message="This replaces what you have added with a ready-made example home, so you can see everything filled in."
        confirmLabel="Load example"
        onConfirm={async () => {
          await exploreExampleHome();
          setConfirm(null);
          navigate('/');
          window.location.reload();
        }}
      />
      <ConfirmDialog
        open={confirm === 'reset'}
        onClose={() => setConfirm(null)}
        title="Start again?"
        message="This clears everything you have added in this browser and takes you back to the sign-up screen."
        confirmLabel="Start again"
        onConfirm={async () => {
          await resetPrototype();
          setConfirm(null);
          navigate('/register');
        }}
      />
    </div>
  );
}
