import { ChevronRight, FileImage, FileText, File as FileIcon, FolderOpen, Upload } from 'lucide-react';
import { useState } from 'react';
import { useQuery } from '@/hooks/useQuery';
import type { Link } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { formatBytes, formatDate } from '@/lib/format';
import { isImage, isPdf } from '@/lib/storage';
import { supabase } from '@/lib/supabase';
import type { HomeDocument } from '@/lib/types';
import { Button } from '../ui/Button';
import { Section } from '../ui/Card';
import { Tag } from '../ui/Badges';
import { EmptyState, ListSkeleton } from '../ui/States';
import { DocumentFormModal, DocumentViewModal } from './DocumentModals';

export function DocumentIcon({ mime }: { mime: string | null }) {
  const Icon = isImage(mime) ? FileImage : isPdf(mime) ? FileText : FileIcon;
  return (
    <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-11 shrink-0 items-center justify-center rounded-xl">
      <Icon className="size-5" aria-hidden />
    </span>
  );
}

export function DocumentRow({ doc, onOpen, attachedTo }: { doc: HomeDocument; onOpen: () => void; attachedTo?: string | null }) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className="border-line bg-surface hover:border-brand-300 hover:bg-surface-muted/50 flex w-full items-center gap-3 rounded-2xl border p-3 text-left transition-colors"
    >
      <DocumentIcon mime={doc.mime_type} />
      <span className="min-w-0 flex-1">
        <span className="text-ink block truncate font-medium">{doc.name}</span>
        <span className="text-muted mt-0.5 block truncate text-sm">
          {[formatDate(doc.created_at, 'short'), formatBytes(doc.size_bytes) || (doc.file_path ? '' : 'No file'), attachedTo]
            .filter(Boolean)
            .join(' · ')}
        </span>
      </span>
      <Tag>{doc.category}</Tag>
      <ChevronRight className="text-muted size-4 shrink-0" aria-hidden />
    </button>
  );
}

interface DocumentsPanelProps {
  propertyId: string;
  link: Link;
  title?: string;
  defaultCategory?: string;
  emptyText?: string;
}

/** Documents attached to one item, with upload/preview. Used on detail pages. */
export function DocumentsPanel({
  propertyId,
  link,
  title = 'Documents & receipts',
  defaultCategory = 'Receipts',
  emptyText,
}: DocumentsPanelProps) {
  const [uploading, setUploading] = useState(false);
  const [viewing, setViewing] = useState<HomeDocument | null>(null);
  const [editing, setEditing] = useState<HomeDocument | null>(null);

  const { data, loading, reload } = useQuery(
    async () =>
      unwrap(
        await supabase.from('documents').select('*').eq(link.key, link.id).order('created_at', { ascending: false }).limit(50),
      ) as HomeDocument[],
    [link.key, link.id],
  );

  return (
    <Section
      title={title}
      icon={FolderOpen}
      action={
        <Button variant="secondary" size="sm" icon={Upload} onClick={() => setUploading(true)}>
          Upload
        </Button>
      }
    >
      {loading && !data ? (
        <ListSkeleton rows={2} />
      ) : !data?.length ? (
        <EmptyState
          compact
          icon={FileText}
          title="No documents yet"
          description={emptyText ?? 'Upload receipts, manuals or certificates.'}
        />
      ) : (
        <ul className="space-y-2">
          {data.map((d) => (
            <li key={d.id}>
              <DocumentRow doc={d} onOpen={() => setViewing(d)} />
            </li>
          ))}
        </ul>
      )}

      <DocumentFormModal
        open={uploading || Boolean(editing)}
        onClose={() => {
          setUploading(false);
          setEditing(null);
        }}
        propertyId={propertyId}
        document={editing}
        fixedLink={link}
        defaultCategory={defaultCategory}
        onSaved={reload}
      />
      <DocumentViewModal
        document={viewing}
        onClose={() => setViewing(null)}
        onEdit={(d) => {
          setViewing(null);
          setEditing(d);
        }}
        onDeleted={reload}
      />
    </Section>
  );
}
