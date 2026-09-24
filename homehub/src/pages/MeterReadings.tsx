import { Camera, Gauge, Pencil, Plus, Trash2 } from 'lucide-react';
import { useMemo, useState } from 'react';
import { DropZone } from '@/components/files/FilePicker';
import { FormModal, toFormValues } from '@/components/forms/EntityForm';
import { MeterChart, type UsagePoint } from '@/components/MeterChart';
import { Button, IconButton } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { Chips, PageHeader } from '@/components/ui/Layout';
import { Modal } from '@/components/ui/Modal';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useUser } from '@/context/AuthContext';
import { useActiveProperty } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useSignedUrls } from '@/hooks/useData';
import { useEditor } from '@/hooks/useEditor';
import { useQuery } from '@/hooks/useQuery';
import { addPhoto, deleteWithPhotos, insertRow, updateRow } from '@/lib/api';
import { METER_TYPES } from '@/lib/constants';
import { friendlyError, unwrap } from '@/lib/errors';
import { METER_FIELDS } from '@/lib/fields';
import { formatDate, formatNumber, todayISO } from '@/lib/format';
import { validateFile } from '@/lib/storage';
import { supabase } from '@/lib/supabase';
import type { MeterReading, MeterType, Photo } from '@/lib/types';

export default function MeterReadings() {
  const property = useActiveProperty();
  const user = useUser();
  const toast = useToast();
  const editor = useEditor<MeterReading>();
  const [type, setType] = useState<MeterType>('electricity');
  const [photo, setPhoto] = useState<File | null>(null);
  const [photoError, setPhotoError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<MeterReading | null>(null);
  const [viewingPhoto, setViewingPhoto] = useState<string | null>(null);
  const meter = METER_TYPES.find((m) => m.value === type)!;

  const { data, loading, error, reload } = useQuery(async () => {
    const readings = unwrap(
      await supabase
        .from('meter_readings')
        .select('*')
        .eq('property_id', property.id)
        .order('reading_date', { ascending: false })
        .limit(500),
    ) as MeterReading[];
    const photos = unwrap(
      await supabase.from('photos').select('*').eq('property_id', property.id).not('meter_reading_id', 'is', null),
    ) as Photo[];
    return { readings, photos };
  }, [property.id]);

  const readings = useMemo(() => (data?.readings ?? []).filter((r) => r.meter_type === type), [data, type]);
  const photoFor = useMemo(() => new Map((data?.photos ?? []).map((p) => [p.meter_reading_id!, p.file_path])), [data]);
  const urls = useSignedUrls(viewingPhoto ? [viewingPhoto] : []);

  // Usage between consecutive readings, oldest first for the chart.
  const usage: UsagePoint[] = useMemo(() => {
    const asc = [...readings].reverse();
    const out: UsagePoint[] = [];
    for (let i = 1; i < asc.length; i++) {
      const diff = Number(asc[i].reading) - Number(asc[i - 1].reading);
      if (diff >= 0) out.push({ date: asc[i].reading_date, from: asc[i - 1].reading_date, usage: diff });
    }
    return out.slice(-24);
  }, [readings]);

  const counts = (t: MeterType) => (data?.readings ?? []).filter((r) => r.meter_type === t).length;

  const openNew = () => {
    setPhoto(null);
    setPhotoError(null);
    editor.openNew();
  };

  const addButton = (
    <Button icon={Plus} onClick={openNew}>
      Add reading
    </Button>
  );

  return (
    <>
      <PageHeader
        title="Meter readings"
        description="Keep a simple history of your electricity, gas and water meters."
        actions={addButton}
      />
      <div className="mb-4">
        <Chips
          label="Meter"
          value={type}
          onChange={setType}
          options={METER_TYPES.map((m) => ({ value: m.value, label: m.label, count: data ? counts(m.value) : undefined }))}
        />
      </div>
      {loading && !data ? (
        <ListSkeleton />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !readings.length ? (
        <EmptyState
          icon={Gauge}
          title={`No ${meter.label.toLowerCase()} readings yet`}
          description="Add a reading every month or so to keep track of usage and check your bills."
          action={addButton}
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-5">
          <div className="min-w-0 lg:col-span-3">
            <Section title={`${meter.label} usage`} icon={Gauge}>
              {usage.length ? (
                <MeterChart points={usage} unit={meter.unit} label={meter.label} />
              ) : (
                <p className="text-muted text-sm">Add another reading to see your usage.</p>
              )}
            </Section>
          </div>
          <div className="min-w-0 lg:col-span-2">
            <Section title="History">
              <ol className="divide-line -mx-1 divide-y">
                {readings.map((r, i) => {
                  const prev = readings[i + 1];
                  const diff = prev ? Number(r.reading) - Number(prev.reading) : null;
                  const photoPath = photoFor.get(r.id);
                  return (
                    <li key={r.id} className="flex items-center gap-2 px-1 py-2.5">
                      <div className="min-w-0 flex-1">
                        <p className="text-ink font-medium tabular-nums">
                          {formatNumber(r.reading, 3)} <span className="text-muted text-sm font-normal">{meter.unit}</span>
                        </p>
                        <p className="text-muted text-sm">
                          {formatDate(r.reading_date)}
                          {diff !== null && diff >= 0 && ` · +${formatNumber(diff)} used`}
                        </p>
                        {r.notes && <p className="text-muted mt-0.5 truncate text-sm">{r.notes}</p>}
                      </div>
                      {photoPath && (
                        <IconButton icon={Camera} label="View meter photo" onClick={() => setViewingPhoto(photoPath)} />
                      )}
                      <IconButton
                        icon={Pencil}
                        label={`Edit reading from ${formatDate(r.reading_date)}`}
                        onClick={() => {
                          setPhoto(null);
                          editor.openEdit(r);
                        }}
                      />
                      <IconButton
                        icon={Trash2}
                        tone="danger"
                        label={`Delete reading from ${formatDate(r.reading_date)}`}
                        onClick={() => setDeleting(r)}
                      />
                    </li>
                  );
                })}
              </ol>
            </Section>
          </div>
        </div>
      )}

      <FormModal
        open={editor.isOpen}
        onClose={editor.close}
        title={editor.row ? 'Edit reading' : 'Add meter reading'}
        size="md"
        fields={METER_FIELDS}
        initial={toFormValues(METER_FIELDS, editor.row, { meter_type: type, reading_date: todayISO() })}
        onSubmit={async (payload) => {
          const saved = editor.row
            ? await updateRow<MeterReading>('meter_readings', editor.row.id, payload)
            : await insertRow<MeterReading>('meter_readings', { ...payload, property_id: property.id });
          if (photo) {
            try {
              await addPhoto(user.id, property.id, photo, { key: 'meter_reading_id', id: saved.id });
            } catch (err) {
              toast.error(`Reading saved, but the photo didn't upload: ${friendlyError(err)}`);
            }
          }
          toast.success('Reading saved');
          setType(saved.meter_type);
          editor.close();
          void reload();
        }}
      >
        <div>
          <p className="text-ink mb-1.5 text-sm font-medium">Photo of the meter (optional)</p>
          <DropZone
            accept="image/*"
            file={photo}
            hint="Handy proof if your bill doesn't look right"
            onFile={(f) => {
              try {
                validateFile(f, 'image');
                setPhoto(f);
                setPhotoError(null);
              } catch (err) {
                setPhotoError(friendlyError(err));
              }
            }}
          />
          {photoError && <p className="mt-1.5 text-sm text-rose-600">{photoError}</p>}
        </div>
      </FormModal>

      <Modal open={Boolean(viewingPhoto)} onClose={() => setViewingPhoto(null)} title="Meter photo" size="lg">
        {viewingPhoto && urls[viewingPhoto] && (
          <img
            src={urls[viewingPhoto]}
            alt="Photo of the meter reading"
            className="mx-auto max-h-[65dvh] rounded-xl object-contain"
          />
        )}
      </Modal>

      <ConfirmDialog
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title="Delete this reading?"
        message={deleting ? `The ${formatDate(deleting.reading_date)} reading will be deleted.` : ''}
        onConfirm={async () => {
          if (!deleting) return;
          await deleteWithPhotos('meter_readings', deleting.id, 'meter_reading_id');
          toast.success('Reading deleted');
          void reload();
        }}
      />
    </>
  );
}
