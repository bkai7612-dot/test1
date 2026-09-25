import { useState, type ReactNode } from 'react';
import { friendlyError } from '@/lib/errors';
import { Button } from './Button';
import { Input } from './Field';
import { Modal } from './Modal';

interface ConfirmDialogProps {
  open: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void> | void;
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  /** When set, the user must type this text to enable the confirm button. */
  confirmText?: string;
}

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = 'Delete',
  confirmText,
}: ConfirmDialogProps) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [typed, setTyped] = useState('');

  const close = () => {
    if (busy) return;
    setError(null);
    setTyped('');
    onClose();
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      await onConfirm();
      setTyped('');
      onClose();
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      open={open}
      onClose={close}
      title={title}
      footer={
        <>
          <Button variant="secondary" onClick={close} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant="danger"
            onClick={confirm}
            loading={busy}
            disabled={Boolean(confirmText) && typed.trim() !== confirmText}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      <div className="text-muted space-y-4 text-sm">
        <div>{message}</div>
        {confirmText && (
          <label className="block">
            <span className="text-ink mb-1.5 block font-medium">
              Type <strong>{confirmText}</strong> to confirm
            </span>
            <Input value={typed} onChange={(e) => setTyped(e.target.value)} autoComplete="off" />
          </label>
        )}
        {error && (
          <p role="alert" className="rounded-xl bg-rose-50 px-3 py-2 text-rose-700 dark:bg-rose-950/40 dark:text-rose-300">
            {error}
          </p>
        )}
      </div>
    </Modal>
  );
}
