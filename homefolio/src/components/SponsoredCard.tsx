import { ExternalLink, Info } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { usePlan } from '@/hooks/usePlan';
import { useQuery } from '@/hooks/useQuery';
import { openExternal } from '@/lib/platform';
import { supabase } from '@/lib/supabase';
import type { AdCampaign, AdPlacement } from '@/lib/types';

/** New users see no sponsored cards in their first week. */
const GRACE_DAYS = 7;
const seenThisSession = new Set<string>();

/** Counts a view or click (anonymous daily totals). Failures are ignored. */
async function recordEvent(campaignId: string, event: 'impression' | 'click'): Promise<void> {
  // Awaiting is what sends the request: Supabase queries are lazy until then.
  await supabase.rpc('record_ad_event', { p_campaign: campaignId, p_event: event });
}

function pickWeighted(list: AdCampaign[]): AdCampaign | null {
  if (!list.length) return null;
  const total = list.reduce((sum, c) => sum + c.weight, 0);
  let roll = Math.random() * total;
  for (const c of list) {
    roll -= c.weight;
    if (roll <= 0) return c;
  }
  return list[0];
}

export function withTracking(url: string): string {
  try {
    const u = new URL(url);
    if (!u.searchParams.has('utm_source')) u.searchParams.set('utm_source', 'homefolio');
    if (!u.searchParams.has('utm_medium')) u.searchParams.set('utm_medium', 'sponsored');
    return u.toString();
  } catch {
    return url;
  }
}

interface CardViewProps {
  ad: Pick<AdCampaign, 'advertiser' | 'headline' | 'body' | 'cta_label' | 'logo_url'>;
  onOpen?: () => void;
  showPlusLink?: boolean;
}

/** The visual card, shared by the live placement and the admin preview. */
export function SponsoredCardView({ ad, onOpen, showPlusLink = true }: CardViewProps) {
  const [why, setWhy] = useState(false);
  return (
    <aside aria-label="Sponsored" className="border-line bg-surface rounded-2xl border p-4">
      <div className="text-muted mb-3 flex items-center justify-between gap-2 text-xs">
        <span className="min-w-0 truncate">
          Sponsored · <span className="text-ink font-medium">{ad.advertiser}</span>
        </span>
        <button
          type="button"
          onClick={() => setWhy((w) => !w)}
          aria-expanded={why}
          className="hover:text-ink inline-flex shrink-0 items-center gap-1 rounded-md px-1 py-0.5 whitespace-nowrap"
        >
          <Info className="size-3.5" aria-hidden />
          <span className="sm:hidden">Why?</span>
          <span className="hidden sm:inline">Why am I seeing this?</span>
        </button>
      </div>
      {why && (
        <p className="bg-surface-muted text-muted mb-3 rounded-xl px-3 py-2 text-xs">
          This is a paid placement chosen for this page. Homefolio doesn't share your information with advertisers.
        </p>
      )}
      <div className="flex items-center gap-3">
        {ad.logo_url ? (
          <img src={ad.logo_url} alt="" className="bg-surface-muted size-10 shrink-0 rounded-lg object-contain" />
        ) : (
          <span className="bg-surface-muted text-muted flex size-10 shrink-0 items-center justify-center rounded-lg text-sm font-semibold">
            {ad.advertiser.slice(0, 1)}
          </span>
        )}
        <div className="min-w-0 flex-1">
          <p className="text-ink font-medium">{ad.headline}</p>
          {ad.body && <p className="text-muted mt-0.5 text-sm">{ad.body}</p>}
        </div>
      </div>
      <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
        {showPlusLink ? (
          <Link to="/upgrade" className="text-muted hover:text-ink text-xs underline-offset-2 hover:underline">
            Remove with Plus
          </Link>
        ) : (
          <span />
        )}
        <button
          type="button"
          onClick={onOpen}
          className="border-line text-ink hover:bg-surface-muted inline-flex min-h-9 items-center gap-1.5 rounded-xl border px-3 text-sm font-medium"
        >
          {ad.cta_label}
          <ExternalLink className="size-3.5" aria-hidden />
        </button>
      </div>
    </aside>
  );
}

/**
 * One small, clearly labelled sponsored card for a page. Chosen by page only;
 * never shown to Plus users or in a user's first week. Only anonymous daily
 * totals are recorded (see record_ad_event).
 */
export function SponsoredCard({ placement, className }: { placement: AdPlacement; className?: string }) {
  const { isPlus, accountAgeDays } = usePlan();
  const hidden = isPlus || accountAgeDays < GRACE_DAYS;
  const { data } = useQuery(
    async () => {
      const { data: rows } = await supabase
        .from('ad_campaigns')
        .select('id, advertiser, placement, headline, body, cta_label, url, logo_url, weight, starts_on, ends_on, active')
        .eq('placement', placement)
        .eq('active', true);
      const today = new Date().toISOString().slice(0, 10);
      return ((rows ?? []) as AdCampaign[]).filter((c) => c.starts_on <= today && c.ends_on >= today);
    },
    [placement],
    !hidden,
  );
  const ad = useMemo(() => pickWeighted(data ?? []), [data]);

  useEffect(() => {
    if (!ad || hidden || seenThisSession.has(ad.id)) return;
    seenThisSession.add(ad.id);
    void recordEvent(ad.id, 'impression');
  }, [ad, hidden]);

  if (hidden || !ad) return null;
  return (
    <div className={className}>
      <SponsoredCardView
        ad={ad}
        onOpen={() => {
          void recordEvent(ad.id, 'click');
          void openExternal(withTracking(ad.url));
        }}
      />
    </div>
  );
}
