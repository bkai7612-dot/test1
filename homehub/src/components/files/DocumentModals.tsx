import { Download, Pencil, Trash2 } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';
import { useUser } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { useSignedUrls } from '@/hooks/useData';
import { addDocument, removeDocument, updateRow, type Link } from '@/lib/api';
import { DOCUMENT_ACCEPT } from '@/lib/constants';
import { friendlyError } from '@/lib/errors';
import { formatBytes, formatDate } from '@/lib/format';
import { getDownloadUrl, isImage, isPdf, validateFile } from '@/lib/storage';
import { supabase } from '@/lib/supabase';
import type { HomeDocument, LinkKey } from '@/lib/types';
import { CategorySelect } from '../forms/CategorySelect';
import { Button } from '../ui/Button';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { Field, Input, Select, Textarea } from '../ui/Field';
import { DetailList } from '../ui/Layout';
import { Modal } from '../ui/Modal';
import { FormError, Spinner } from '../ui/States';
import { DropZone } from './FilePicker';

const DOC_LINK_KEYS: LinkKey[] = [
  'room_id',
  'appliance_id',
  'inventory_item_id',
  'maintenance_task_id',
  'insurance_policy_id',
  'utility_id',
  'council_tax_id',
];

export function documentLink(doc: HomeDocument): Link | null {
  for (const key of DOC_LINK_KEYS) {
    const id = doc[key as keyof HomeDocument] as string | null;
    if (id) return { key, id };
  }
  return null;
}

interface LinkOption {
  group: string;
  value: string;
  label: string;
}

/** Items in the property a document can be attached to, loaded when the picker opens. */
function useLinkOptions(propertyId: string, enabled: boolean) {
  const [options, setOptions] = useState<LinkOption[]>([]);
  useEffect(() => {
    if (!enabled) return;
    const byProperty = (table: string, cols: string) =>
      supabase.from(table).select(cols).eq('property_id', propertyId).limit(200);
    Promise.all([
      byProperty('appliances', 'id, name').order('name'),
      byProperty('inventory_items', 'id, name').order('name'),
      byProperty('rooms', 'id, name').order('name'),
      byProperty('insurance_policies', 'id, provider, policy_type'),
      byProperty('utilities', 'id, provider, utility_type, label'),
      byProperty('maintenance_tasks', 'id, title, due_date').is('completed_at', null).order('due_date'),
    ])
      .then((results) => {
        const [a, i, r, ins, u, m] = results.map((res) => (res.data ?? []) as unknown as Record<string, string>[]);
        setOptions([
          ...a.map((x) => ({ group: 'Appliances', value: `appliance_id:${x.id}`, label: x.name })),
          ...i.map((x) => ({ group: 'Inventory', value: `inventory_item_id:${x.id}`, label: x.name })),
          ...r.map((x) => ({ group: 'Rooms', value: `room_id:${x.id}`, label: x.name })),
          ...ins.map((x) => ({ group: 'Insurance', value: `insurance_policy_id:${x.id}`, label: x.provider || x.policy_type })),
          ...u.map((x) => ({
            group: 'Utilities',
            value: `utility_id:${x.id}`,
            label: [x.label || x.utility_type, x.provider].filter(Boolean).join(' – '),
          })),
          ...m.map((x) => ({ group: 'Maintenance', value: `maintenance_task_id:${x.id}`, label: x.title })),
        ]);
      })
      .catch(() => setOptions([]));
  }, [propertyId, enabled]);
  return options;
}

function parseLink(value: string): Link | null {
  if (!value) return null;
  const [key, id] = value.split(':');
  return { key: key as LinkKey, id };
}

interface DocumentFormModalProps {
  open: boolean;
  onClose: () => void;
  propertyId: string;
  /** Existing document to edit; omit to upload a new one. */
  document?: HomeDocument | null;
  /** Fixed attachment when uploading from an item's page. */
  fixedLink?: Link;
  defaultCategory?: string;
  onSaved: () => void;
}

export function DocumentFormModal({
  open,
  onClose,
  propertyId,
  document,
  fixedLink,
  defaultCategory = 'Other',
  onSaved,
}: DocumentFormModalProps) {
  const user = useUser();
  const toast = useToast();
  const editing = Boolean(document);
  const [file, setFile] = useState<File | null>(null);
  const [name, setName] = useState('');
  const [category, setCategory] = useState(defaultCategory);
  const [notes, setNotes] = useState('');
  const [link, setLink] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const linkOptions = useLinkOptions(propertyId, open && !fixedLink);

  useEffect(() => {
    if (!open) return;
    setFile(null);
    setError(null);
    setName(document?.name ?? '');
    setCategory(document?.category ?? defaultCategory);
    setNotes(document?.notes ?? '');
    const l = document ? documentLink(document) : null;
    setLink(l ? `${l.key}:${l.id}` : '');
  }, [open, document, defaultCategory]);

  const chooseFile = (f: File) => {
    try {
      validateFile(f, 'document');
      setFile(f);
      setError(null);
      if (!name) setName(f.name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' '));
    } catch (err) {
      setError(friendlyError(err));
    }
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!editing && !file) return setError('Please choose a file to upload.');
    if (!name.trim()) return setError('Please give the document a name.');
    setBusy(true);
    setError(null);
    try {
      const chosen = fixedLink ?? parseLink(link);
      if (document) {
        const cleared = Object.fromEntries(DOC_LINK_KEYS.map((k) => [k, null]));
        await updateRow('documents', document.id, {
          name: name.trim(),
          category: category || 'Other',
          notes: notes.trim() || null,
          ...(fixedLink ? {} : { ...cleared, ...(chosen ? { [chosen.key]: chosen.id } : {}) }),
        });
        toast.success('Document updated');
      } else if (file) {
        await addDocument(user.id, propertyId, file, {
          name: name.trim(),
          category: category || 'Other',
          notes: notes.trim() || null,
          link: chosen,
        });
        toast.success('Document uploaded');
      }
      onSaved();
      onClose();
    } catch (err) {
      setError(friendlyError(err, "We couldn't save that document. Please try again."));
    } finally {
      setBusy(false);
    }
  };

  const groups = [...new Set(linkOptions.map((o) => o.group))];

  return (
    <Modal
      open={open}
      onClose={() => !busy && onClose()}
      title={editing ? 'Edit document' : 'Upload document'}
      description={editing ? undefined : 'PDF, photos, Word or text files up to 20 MB.'}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button type="submit" form="document-form" loading={busy}>
            {editing ? 'Save' : 'Upload'}
          </Button>
        </>
      }
    >
      <form id="document-form" onSubmit={submit} className="space-y-4" noValidate>
        <FormError message={error} />
        {!editing && (
          <DropZone
            accept={DOCUMENT_ACCEPT}
            onFile={chooseFile}
            file={file}
            hint="PDF, JPG, PNG, HEIC, Word or text · max 20 MB"
          />
        )}
        <Field label="Name" required>
          {(a) => (
            <Input
              {...a}
              value={name}
              maxLength={200}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Washing machine receipt"
            />
          )}
        </Field>
        <Field label="Category">{(a) => <CategorySelect {...a} kind="document" value={category} onChange={setCategory} />}</Field>
        {!fixedLink && (
          <Field label="Attach to (optional)" hint="Link it to an item so it shows on that item's page.">
            {(a) => (
              <Select {...a} value={link} onChange={(e) => setLink(e.target.value)}>
                <option value="">Whole property</option>
                {groups.map((g) => (
                  <optgroup key={g} label={g}>
                    {linkOptions
                      .filter((o) => o.group === g)
                      .map((o) => (
                        <option key={o.value} value={o.value}>
                          {o.label}
                        </option>
                      ))}
                  </optgroup>
                ))}
              </Select>
            )}
          </Field>
        )}
        <Field label="Notes">{(a) => <Textarea {...a} value={notes} onChange={(e) => setNotes(e.target.value)} />}</Field>
      </form>
    </Modal>
  );
}

interface DocumentViewModalProps {
  document: HomeDocument | null;
  onClose: () => void;
  onEdit: (doc: HomeDocument) => void;
  onDeleted: () => void;
  attachedTo?: string | null;
}

/** Preview (images and PDFs), download, edit and delete a document. */
export function DocumentViewModal({ document, onClose, onEdit, onDeleted, attachedTo }: DocumentViewModalProps) {
  const toast = useToast();
  const [confirming, setConfirming] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const urls = useSignedUrls([document?.file_path]);
  const url = document?.file_path ? urls[document.file_path] : undefined;

  const download = async () => {
    if (!document?.file_path) return;
    setDownloading(true);
    try {
      const href = await getDownloadUrl(document.file_path, document.file_name ?? document.name);
      window.location.assign(href);
    } catch (err) {
      toast.error(err);
    } finally {
      setDownloading(false);
    }
  };

  return (
    <>
      <Modal
        open={Boolean(document) && !confirming}
        onClose={onClose}
        title={document?.name ?? ''}
        size="xl"
        footer={
          document && (
            <>
              <Button variant="secondary" icon={Trash2} onClick={() => setConfirming(true)}>
                Delete
              </Button>
              <Button variant="secondary" icon={Pencil} onClick={() => onEdit(document)}>
                Edit
              </Button>
              {document.file_path && (
                <Button icon={Download} onClick={download} loading={downloading}>
                  Download
                </Button>
              )}
            </>
          )
        }
      >
        {document && (
          <div className="space-y-5">
            {document.file_path ? (
              isImage(document.mime_type) ? (
                url ? (
                  <img src={url} alt={document.name} className="mx-auto max-h-[55dvh] rounded-xl object-contain" />
                ) : (
                  <Spinner />
                )
              ) : isPdf(document.mime_type) ? (
                url ? (
                  <iframe src={url} title={document.name} className="border-line h-[55dvh] w-full rounded-xl border bg-white" />
                ) : (
                  <Spinner />
                )
              ) : (
                <p className="bg-surface-muted text-muted rounded-xl p-4 text-sm">
                  A preview isn't available for this file type. Use Download to open it.
                </p>
              )
            ) : (
              <p className="bg-surface-muted text-muted rounded-xl p-4 text-sm">No file is attached to this record.</p>
            )}
            <DetailList
              items={[
                { label: 'Category', value: document.category },
                { label: 'Attached to', value: attachedTo },
                { label: 'Uploaded', value: formatDate(document.created_at) },
                { label: 'File', value: [document.file_name, formatBytes(document.size_bytes)].filter(Boolean).join(' · ') },
                { label: 'Notes', value: document.notes, full: true },
              ]}
            />
          </div>
        )}
      </Modal>
      <ConfirmDialog
        open={confirming}
        onClose={() => setConfirming(false)}
        title="Delete this document?"
        message={`"${document?.name}" and its file will be permanently deleted.`}
        onConfirm={async () => {
          if (!document) return;
          await removeDocument(document);
          toast.success('Document deleted');
          onDeleted();
          onClose();
        }}
      />
    </>
  );
}
