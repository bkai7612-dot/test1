import { X } from 'lucide-react';
import { useEffect, useId, useRef, type ReactNode } from 'react';
import { cn } from '@/lib/cn';

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  footer?: ReactNode;
  size?: 'md' | 'lg' | 'xl';
}

/**
 * Built on the native <dialog> element for focus trapping, Escape handling and
 * correct stacking. Slides up as a sheet on phones, centred on larger screens.
 */
export function Modal({ open, onClose, title, description, children, footer, size = 'md' }: ModalProps) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      dialog.showModal();
      // Focus the dialog itself rather than its first button (the close "X"),
      // so keyboard users start at the top without a stray focus ring.
      dialog.focus();
    }
    if (!open && dialog.open) dialog.close();
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  return (
    <dialog
      ref={ref}
      aria-labelledby={titleId}
      tabIndex={-1}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      onClick={(e) => {
        if (e.target === ref.current) onClose();
      }}
      className={cn(
        'text-ink m-0 mt-auto w-full max-w-none bg-transparent p-0 outline-none backdrop:bg-black/40 sm:m-auto',
        size === 'md' && 'sm:max-w-lg',
        size === 'lg' && 'sm:max-w-2xl',
        size === 'xl' && 'sm:max-w-4xl',
      )}
    >
      {open && (
        <div className="border-line bg-surface flex max-h-[92dvh] flex-col rounded-t-3xl border shadow-xl sm:max-h-[88dvh] sm:rounded-2xl">
          <div className="border-line flex items-start justify-between gap-4 border-b px-5 py-4">
            <div className="min-w-0">
              <h2 id={titleId} className="text-lg font-semibold">
                {title}
              </h2>
              {description && <p className="text-muted mt-0.5 text-sm">{description}</p>}
            </div>
            <button
              type="button"
              onClick={onClose}
              className="text-muted hover:bg-surface-muted hover:text-ink -mr-2 inline-flex size-10 shrink-0 items-center justify-center rounded-xl"
              aria-label="Close"
            >
              <X className="size-5" />
            </button>
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>
          {footer && (
            <div className="border-line flex flex-col-reverse gap-2 border-t px-5 py-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:flex-row sm:justify-end">
              {footer}
            </div>
          )}
        </div>
      )}
    </dialog>
  );
}
