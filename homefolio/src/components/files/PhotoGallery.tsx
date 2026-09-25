import { Camera, ImageIcon, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { useUser } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { useSignedUrls } from '@/hooks/useData';
import { useQuery } from '@/hooks/useQuery';
import { addPhoto, removePhoto, type Link } from '@/lib/api';
import { unwrap } from '@/lib/errors';
import { takeOrPickPhoto } from '@/lib/native';
import { isNative } from '@/lib/platform';
import { supabase } from '@/lib/supabase';
import type { LinkKey, Photo } from '@/lib/types';
import { Button } from '../ui/Button';
import { Section } from '../ui/Card';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { Modal } from '../ui/Modal';
import { EmptyState, Skeleton } from '../ui/States';
import { FileButton } from './FilePicker';

const LINK_KEYS: LinkKey[] = ['room_id', 'appliance_id', 'inventory_item_id', 'maintenance_task_id', 'meter_reading_id'];
const PAGE = 12;

interface PhotoGalleryProps {
  propertyId: string;
  /** Omit for photos of the property itself. */
  link?: Link;
  title?: string;
  itemName: string;
}

export function PhotoGallery({ propertyId, link, title = 'Photos', itemName }: PhotoGalleryProps) {
  const user = useUser();
  const toast = useToast();
  const [limit, setLimit] = useState(PAGE);
  const [uploading, setUploading] = useState(false);
  const [viewing, setViewing] = useState<Photo | null>(null);
  const [deleting, setDeleting] = useState<Photo | null>(null);

  const { data, loading, reload } = useQuery(async () => {
    let q = supabase.from('photos').select('*').eq('property_id', propertyId);
    if (link) q = q.eq(link.key, link.id);
    else for (const k of LINK_KEYS) q = q.is(k, null);
    return unwrap(await q.order('created_at', { ascending: false }).limit(limit + 1)) as Photo[];
  }, [propertyId, link?.key, link?.id, limit]);

  const photos = (data ?? []).slice(0, limit);
  const hasMore = (data?.length ?? 0) > limit;
  const urls = useSignedUrls(photos.map((p) => p.file_path));

  const upload = async (files: File[]) => {
    setUploading(true);
    let ok = 0;
    for (const file of files) {
      try {
        await addPhoto(user.id, propertyId, file, link);
        ok++;
      } catch (err) {
        toast.error(err);
      }
    }
    setUploading(false);
    if (ok) {
      toast.success(ok === 1 ? 'Photo added' : `${ok} photos added`);
      void reload();
    }
  };

  return (
    <Section
      title={title}
      icon={ImageIcon}
      action={
        isNative ? (
          <Button
            variant="secondary"
            size="sm"
            icon={Camera}
            loading={uploading}
            onClick={async () => {
              const file = await takeOrPickPhoto();
              if (file) await upload([file]);
            }}
          >
            Add photo
          </Button>
        ) : (
          <FileButton accept="image/*" multiple onFiles={upload} label="Add photos" icon={Camera} loading={uploading} />
        )
      }
    >
      {loading && !data ? (
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
          <Skeleton className="aspect-square" />
          <Skeleton className="aspect-square" />
          <Skeleton className="aspect-square" />
        </div>
      ) : photos.length === 0 ? (
        <EmptyState
          compact
          icon={Camera}
          title="No photos yet"
          description="Photos help with insurance claims and remembering details."
        />
      ) : (
        <>
          <ul className="grid grid-cols-3 gap-2 sm:grid-cols-4">
            {photos.map((p, i) => (
              <li key={p.id} className="group relative">
                <button
                  type="button"
                  onClick={() => setViewing(p)}
                  className="bg-surface-muted block aspect-square w-full overflow-hidden rounded-xl"
                >
                  {urls[p.file_path] ? (
                    <img
                      src={urls[p.file_path]}
                      alt={p.caption ?? `Photo ${i + 1} of ${itemName}`}
                      loading="lazy"
                      decoding="async"
                      className="size-full object-cover transition-transform group-hover:scale-105"
                    />
                  ) : (
                    <Skeleton className="size-full rounded-none" />
                  )}
                </button>
              </li>
            ))}
          </ul>
          {hasMore && (
            <Button variant="ghost" size="sm" className="mt-3 w-full" onClick={() => setLimit((l) => l + PAGE)}>
              Show more photos
            </Button>
          )}
        </>
      )}

      <Modal open={Boolean(viewing)} onClose={() => setViewing(null)} title={`Photo of ${itemName}`} size="xl">
        {viewing && (
          <div className="space-y-4">
            <img
              src={urls[viewing.file_path]}
              alt={viewing.caption ?? `Photo of ${itemName}`}
              className="mx-auto max-h-[65dvh] w-auto rounded-xl object-contain"
            />
            <div className="flex justify-end">
              <Button
                variant="secondary"
                icon={Trash2}
                onClick={() => {
                  setDeleting(viewing);
                  setViewing(null);
                }}
              >
                Remove photo
              </Button>
            </div>
          </div>
        )}
      </Modal>

      <ConfirmDialog
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title="Remove this photo?"
        message="The photo will be permanently deleted."
        confirmLabel="Remove"
        onConfirm={async () => {
          if (!deleting) return;
          await removePhoto(deleting);
          toast.success('Photo removed');
          void reload();
        }}
      />
    </Section>
  );
}
