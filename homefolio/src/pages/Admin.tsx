import { BarChart3, Copy, Megaphone, Pause, Pencil, Play, Plus, Trash2, Upload } from 'lucide-react';
import { useMemo, useRef, useState } from 'react';
import { FormModal, toFormValues, type FieldDef } from '@/components/forms/EntityForm';
import { SponsoredCardView } from '@/components/SponsoredCard';
import { StatusBadge } from '@/components/ui/Badges';
import { Button, IconButton } from '@/components/ui/Button';
import { Card, Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { Field, Input } from '@/components/ui/Field';
import { Chips, PageHeader } from '@/components/ui/Layout';
import { EmptyState, ErrorState, ListSkeleton } from '@/components/ui/States';
import { useToast } from '@/context/ToastContext';
import { useEditor } from '@/hooks/useEditor';
import { usePlan } from '@/hooks/usePlan';
import { useQuery } from '@/hooks/useQuery';
import { deleteRow, insertRow, updateRow } from '@/lib/api';
import { FriendlyError, unwrap } from '@/lib/errors';
import { formatDate, formatMoney, todayISO, toISODate } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { AdCampaign } from '@/lib/types';
import NotFound from './NotFound';

const PLACEMENTS = [
  { value: 'dashboard', label: 'Home screen' },
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'appliances', label: 'Appliances' },
  { value: 'utilities', label: 'Utilities' },
  { value: 'insurance', label: 'Insurance' },
];

const FIELDS: FieldDef[] = [
  { name: 'advertiser', label: 'Advertiser', type: 'text', required: true, maxLength: 80, half: true },
  { name: 'placement', label: 'Placement', type: 'select', required: true, options: PLACEMENTS, half: true },
  { name: 'headline', label: 'Headline', type: 'text', required: true, maxLength: 40, hint: 'Up to 40 characters.' },
  { name: 'body', label: 'Text', type: 'text', maxLength: 90, hint: 'Up to 90 characters.' },
  {
    name: 'cta_label',
    label: 'Button text',
    type: 'text',
    required: true,
    maxLength: 18,
    half: true,
    placeholder: 'Get a quote',
  },
  { name: 'url', label: 'Link', type: 'url', required: true, half: true, placeholder: 'https://' },
  { name: 'starts_on', label: 'Starts', type: 'date', required: true, half: true },
  { name: 'ends_on', label: 'Ends', type: 'date', required: true, half: true },
  { name: 'price_per_month', label: 'Price per month', type: 'money', half: true, hint: 'For your records only.' },
  {
    name: 'weight',
    label: 'Share of views',
    type: 'number',
    min: 1,
    max: 100,
    step: '1',
    half: true,
    hint: 'When two ads share a placement, 2 is shown twice as often as 1.',
  },
  { name: 'active', label: 'Live', type: 'toggle', hint: 'Turn off to pause without deleting.' },
  { name: 'notes', label: 'Notes', type: 'textarea', placeholder: 'Contact, invoice number, contract details' },
];

function campaignStatus(c: AdCampaign) {
  const today = todayISO();
  if (!c.active) return { status: 'none' as const, label: 'Paused' };
  if (c.ends_on < today) return { status: 'expired' as const, label: 'Ended' };
  if (c.starts_on > today) return { status: 'upcoming' as const, label: `Starts ${formatDate(c.starts_on, 'short')}` };
  return { status: 'active' as const, label: 'Live' };
}

function monthRange(month: string): [string, string] {
  const [y, m] = month.split('-').map(Number);
  return [toISODate(new Date(y, m - 1, 1)), toISODate(new Date(y, m, 0))];
}

/** Admin-only: manage sponsored cards and see how they perform. */
export default function Admin() {
  const { isAdmin } = usePlan();
  const [tab, setTab] = useState<'campaigns' | 'report'>('campaigns');
  if (!isAdmin) return <NotFound />;
  return (
    <>
      <PageHeader title="Advertising" description="Sponsored cards shown to free users. Only admins can see this page." />
      <div className="mb-5">
        <Chips
          label="Section"
          value={tab}
          onChange={setTab}
          options={[
            { value: 'campaigns', label: 'Campaigns' },
            { value: 'report', label: 'Monthly report' },
          ]}
        />
      </div>
      {tab === 'campaigns' ? <Campaigns /> : <Report />}
    </>
  );
}

function Campaigns() {
  const toast = useToast();
  const editor = useEditor<AdCampaign>();
  const [deleting, setDeleting] = useState<AdCampaign | null>(null);
  const [logoFor, setLogoFor] = useState<AdCampaign | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const { data, loading, error, reload } = useQuery(
    async () => unwrap(await supabase.from('ad_campaigns').select('*').order('ends_on', { ascending: false })) as AdCampaign[],
    [],
  );

  const uploadLogo = async (campaign: AdCampaign, file: File) => {
    try {
      if (!['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'].includes(file.type)) {
        throw new FriendlyError('Use a PNG, JPG, WEBP or SVG logo.');
      }
      if (file.size > 1024 * 1024) throw new FriendlyError('Logos must be under 1 MB.');
      const path = `${campaign.id}/${Date.now()}-${file.name.replace(/[^\w.-]+/g, '-')}`;
      const { error: upErr } = await supabase.storage.from('ad-creatives').upload(path, file, { contentType: file.type });
      if (upErr) throw upErr;
      const { data: pub } = supabase.storage.from('ad-creatives').getPublicUrl(path);
      await updateRow('ad_campaigns', campaign.id, { logo_url: pub.publicUrl });
      toast.success('Logo updated');
      void reload();
    } catch (err) {
      toast.error(err);
    }
  };

  const addButton = (
    <Button icon={Plus} onClick={editor.openNew}>
      New campaign
    </Button>
  );

  return (
    <>
      <div className="mb-4 flex justify-end">{addButton}</div>
      {loading && !data ? (
        <ListSkeleton rows={2} />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !data?.length ? (
        <EmptyState
          icon={Megaphone}
          title="No campaigns yet"
          description="When you sell a placement, add it here. It appears to free users on the chosen page between the start and end dates."
          action={addButton}
        />
      ) : (
        <ul className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {data.map((c) => {
            const s = campaignStatus(c);
            return (
              <li key={c.id}>
                <Card className="space-y-3 p-4">
                  <div className="flex flex-wrap items-center gap-2">
                    <StatusBadge status={s.status} label={s.label} />
                    <span className="text-muted text-sm">
                      {PLACEMENTS.find((p) => p.value === c.placement)?.label} · {formatDate(c.starts_on, 'short')} –{' '}
                      {formatDate(c.ends_on, 'short')}
                      {c.price_per_month ? ` · ${formatMoney(c.price_per_month)}/month` : ''}
                    </span>
                  </div>
                  <SponsoredCardView ad={c} showPlusLink={false} onOpen={() => window.open(c.url, '_blank', 'noopener')} />
                  <div className="flex flex-wrap gap-1">
                    <IconButton icon={Pencil} label={`Edit ${c.advertiser}`} onClick={() => editor.openEdit(c)} />
                    <IconButton
                      icon={Upload}
                      label="Upload logo"
                      onClick={() => {
                        setLogoFor(c);
                        fileInput.current?.click();
                      }}
                    />
                    <IconButton
                      icon={c.active ? Pause : Play}
                      label={c.active ? 'Pause' : 'Resume'}
                      onClick={async () => {
                        try {
                          await updateRow('ad_campaigns', c.id, { active: !c.active });
                          void reload();
                        } catch (err) {
                          toast.error(err);
                        }
                      }}
                    />
                    <IconButton icon={Trash2} tone="danger" label={`Delete ${c.advertiser}`} onClick={() => setDeleting(c)} />
                  </div>
                </Card>
              </li>
            );
          })}
        </ul>
      )}

      <input
        ref={fileInput}
        type="file"
        accept="image/png,image/jpeg,image/webp,image/svg+xml"
        className="sr-only"
        tabIndex={-1}
        aria-hidden
        onChange={(e) => {
          const f = e.target.files?.[0];
          e.target.value = '';
          if (f && logoFor) void uploadLogo(logoFor, f);
        }}
      />

      <FormModal
        open={editor.isOpen}
        onClose={editor.close}
        title={editor.row ? `Edit ${editor.row.advertiser}` : 'New campaign'}
        fields={FIELDS}
        initial={toFormValues(FIELDS, editor.row, {
          placement: 'dashboard',
          cta_label: 'Learn more',
          starts_on: todayISO(),
          ends_on: toISODate(new Date(Date.now() + 30 * 86_400_000)),
          weight: '1',
          active: true,
        })}
        extraValidate={(v) => ({
          ...(v.ends_on && v.starts_on && v.ends_on < v.starts_on ? { ends_on: 'End date must be after the start.' } : {}),
          ...(v.url && !String(v.url).startsWith('https://') ? { url: 'Links must start with https://' } : {}),
        })}
        onSubmit={async (payload) => {
          const values = { ...payload, weight: payload.weight ?? 1 };
          if (editor.row) await updateRow('ad_campaigns', editor.row.id, values);
          else await insertRow('ad_campaigns', values);
          toast.success('Campaign saved. Add a logo with the upload button.');
          editor.close();
          void reload();
        }}
      />
      <ConfirmDialog
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title={`Delete ${deleting?.advertiser}?`}
        message="The campaign and its view counts will be deleted. To stop it temporarily, pause it instead."
        onConfirm={async () => {
          if (!deleting) return;
          await deleteRow('ad_campaigns', deleting.id);
          toast.success('Campaign deleted');
          void reload();
        }}
      />
    </>
  );
}

interface ReportRow {
  campaign_id: string;
  advertiser: string;
  placement: string;
  views: number;
  clicks: number;
}

function Report() {
  const toast = useToast();
  const [month, setMonth] = useState(() => todayISO().slice(0, 7));
  const [from, to] = monthRange(month);
  const { data, loading, error, reload } = useQuery(
    async () => unwrap(await supabase.rpc('ad_report', { p_from: from, p_to: to })) as ReportRow[],
    [from, to],
  );
  const rows = useMemo(() => (data ?? []).filter((r) => Number(r.views) > 0 || Number(r.clicks) > 0), [data]);

  const asText = (r: ReportRow) => {
    const rate = Number(r.views) ? ((100 * Number(r.clicks)) / Number(r.views)).toFixed(2) : '0.00';
    return `${r.advertiser} — ${PLACEMENTS.find((p) => p.value === r.placement)?.label} — ${formatDate(from)} to ${formatDate(to)}: ${Number(r.views).toLocaleString('en-GB')} views, ${Number(r.clicks).toLocaleString('en-GB')} clicks (${rate}% click rate)`;
  };

  return (
    <Section
      title="Monthly report"
      icon={BarChart3}
      description="Views and clicks per campaign. Copy a line to send to the advertiser."
    >
      <Field label="Month" className="mb-4 max-w-xs">
        {(a) => <Input {...a} type="month" value={month} onChange={(e) => e.target.value && setMonth(e.target.value)} />}
      </Field>
      {loading && !data ? (
        <ListSkeleton rows={2} />
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : !rows.length ? (
        <p className="text-muted text-sm">No views recorded in this month.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="text-muted text-xs uppercase">
              <tr>
                <th className="py-2 pr-4 font-medium">Advertiser</th>
                <th className="py-2 pr-4 font-medium">Placement</th>
                <th className="py-2 pr-4 text-right font-medium">Views</th>
                <th className="py-2 pr-4 text-right font-medium">Clicks</th>
                <th className="py-2 pr-4 text-right font-medium">Click rate</th>
                <th className="py-2" />
              </tr>
            </thead>
            <tbody className="divide-line divide-y tabular-nums">
              {rows.map((r) => (
                <tr key={r.campaign_id}>
                  <td className="py-2 pr-4">{r.advertiser}</td>
                  <td className="py-2 pr-4">{PLACEMENTS.find((p) => p.value === r.placement)?.label}</td>
                  <td className="py-2 pr-4 text-right">{Number(r.views).toLocaleString('en-GB')}</td>
                  <td className="py-2 pr-4 text-right">{Number(r.clicks).toLocaleString('en-GB')}</td>
                  <td className="py-2 pr-4 text-right">
                    {Number(r.views) ? `${((100 * Number(r.clicks)) / Number(r.views)).toFixed(2)}%` : '—'}
                  </td>
                  <td className="py-1 text-right">
                    <IconButton
                      icon={Copy}
                      label="Copy summary"
                      onClick={async () => {
                        try {
                          await navigator.clipboard.writeText(asText(r));
                          toast.success('Copied');
                        } catch {
                          toast.error("Couldn't copy. Select the row and copy it manually.");
                        }
                      }}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Section>
  );
}
