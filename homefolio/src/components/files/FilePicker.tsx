import { Upload, type LucideIcon } from 'lucide-react';
import { useRef, useState, type DragEvent } from 'react';
import { cn } from '@/lib/cn';
import { Button } from '../ui/Button';

interface FileButtonProps {
  accept: string;
  multiple?: boolean;
  onFiles: (files: File[]) => void;
  label: string;
  icon?: LucideIcon;
  loading?: boolean;
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md';
}

/** A button that opens the file picker (camera or library on phones). */
export function FileButton({
  accept,
  multiple,
  onFiles,
  label,
  icon = Upload,
  loading,
  variant = 'secondary',
  size = 'sm',
}: FileButtonProps) {
  const input = useRef<HTMLInputElement>(null);
  return (
    <>
      <Button variant={variant} size={size} icon={icon} loading={loading} onClick={() => input.current?.click()}>
        {label}
      </Button>
      <input
        ref={input}
        type="file"
        accept={accept}
        multiple={multiple}
        className="sr-only"
        tabIndex={-1}
        aria-hidden
        onChange={(e) => {
          const files = Array.from(e.target.files ?? []);
          e.target.value = '';
          if (files.length) onFiles(files);
        }}
      />
    </>
  );
}

interface DropZoneProps {
  accept: string;
  onFile: (file: File) => void;
  file: File | null;
  hint: string;
}

/** Large tap/drop target for choosing a single file inside forms. */
export function DropZone({ accept, onFile, file, hint }: DropZoneProps) {
  const input = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setOver(false);
    const f = e.dataTransfer.files?.[0];
    if (f) onFile(f);
  };

  return (
    <div>
      <button
        type="button"
        onClick={() => input.current?.click()}
        onDragOver={(e) => {
          e.preventDefault();
          setOver(true);
        }}
        onDragLeave={() => setOver(false)}
        onDrop={onDrop}
        className={cn(
          'flex w-full flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed px-4 py-8 text-center transition-colors',
          over
            ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/30'
            : 'border-line hover:border-brand-400 hover:bg-surface-muted',
        )}
      >
        <Upload className="text-brand-fg size-6" aria-hidden />
        {file ? (
          <span className="text-ink max-w-full truncate text-sm font-medium">{file.name}</span>
        ) : (
          <span className="text-ink text-sm font-medium">Tap to choose a file, or drag it here</span>
        )}
        <span className="text-muted text-xs">{file ? 'Tap to choose a different file' : hint}</span>
      </button>
      <input
        ref={input}
        type="file"
        accept={accept}
        className="sr-only"
        tabIndex={-1}
        aria-hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = '';
          if (f) onFile(f);
        }}
      />
    </div>
  );
}
