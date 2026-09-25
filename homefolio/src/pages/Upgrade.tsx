import { Check, ExternalLink, RotateCcw, Sparkles } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Button, LinkButton } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { PageHeader } from '@/components/ui/Layout';
import { FormError, Skeleton } from '@/components/ui/States';
import { useAuth, useUser } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { usePlan } from '@/hooks/usePlan';
import { cn } from '@/lib/cn';
import { friendlyError } from '@/lib/errors';
import { formatDate } from '@/lib/format';
import { isDesktop, openExternal, platform, WEBSITE_URL } from '@/lib/platform';
import {
  FALLBACK_PRICES,
  getPlanOptions,
  manageSubscriptionUrl,
  purchase,
  purchasesAvailable,
  restorePurchases,
  type PlanKind,
  type PlanOption,
} from '@/lib/purchases';
import { SITE_URL } from '@/lib/supabase';

const BENEFITS = [
  'Unlimited properties',
  '25 GB for photos and documents (instead of 1 GB)',
  'No sponsored cards',
  'Every new Plus feature as it arrives',
  'Support Homefolio staying independent',
];

const REASONS: Record<string, string> = {
  properties: 'The free plan includes one property. Upgrade to add more homes.',
  storage: "You've used your 1 GB of free storage. Plus gives you 25 GB.",
};

const LABELS: Record<PlanKind, { title: string; period: string; note?: string }> = {
  annual: { title: 'Yearly', period: 'per year', note: 'Best value' },
  monthly: { title: 'Monthly', period: 'per month' },
  lifetime: { title: 'Lifetime', period: 'once', note: 'Pay once, keep Plus for good' },
};

/** Waits for the payment webhook to update the plan (usually a few seconds). */
async function waitForPlus(refresh: () => Promise<{ plan: string } | null>, tries = 12): Promise<boolean> {
  for (let i = 0; i < tries; i++) {
    const p = await refresh();
    if (p?.plan === 'plus') return true;
    await new Promise((r) => setTimeout(r, 2000));
  }
  return false;
}

export default function Upgrade() {
  const user = useUser();
  const { refreshProfile } = useAuth();
  const { isPlus, isLifetime, expiresAt, source } = usePlan();
  const toast = useToast();
  const [params] = useSearchParams();
  const reason = REASONS[params.get('reason') ?? ''];
  const [options, setOptions] = useState<PlanOption[] | null>(null);
  const [selected, setSelected] = useState<PlanKind>('annual');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [manageUrl, setManageUrl] = useState<string | null>(null);
  const canBuy = purchasesAvailable();

  useEffect(() => {
    if (!canBuy || isPlus) return;
    getPlanOptions(user.id)
      .then((list) => {
        setOptions(list);
        if (list.length && !list.some((o) => o.kind === 'annual')) setSelected(list[0].kind);
      })
      .catch(() => setOptions([]));
  }, [canBuy, isPlus, user.id]);

  useEffect(() => {
    if (!isPlus || isLifetime) return;
    manageSubscriptionUrl(user.id, source)
      .then(setManageUrl)
      .catch(() => setManageUrl(null));
  }, [isPlus, isLifetime, source, user.id]);

  const buy = async () => {
    const option = options?.find((o) => o.kind === selected);
    if (!option) return;
    setBusy(true);
    setError(null);
    try {
      const outcome = await purchase(user.id, option, user.email);
      if (outcome === 'cancelled') return;
      const active = await waitForPlus(refreshProfile);
      toast.success(active ? 'Welcome to Homefolio Plus!' : 'Payment received. Plus will switch on in a moment.');
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  const restore = async () => {
    setBusy(true);
    setError(null);
    try {
      const found = await restorePurchases(user.id);
      if (found && (await waitForPlus(refreshProfile, 6))) toast.success('Your Plus purchase has been restored.');
      else toast.error('No previous Plus purchase was found for this Apple or Google account.');
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  if (isPlus) {
    return (
      <>
        <PageHeader title="Homefolio Plus" back={{ to: '/settings', label: 'Settings' }} />
        <Card className="p-6 text-center">
          <Sparkles className="text-brand-fg mx-auto size-10" aria-hidden />
          <h2 className="mt-3 text-xl font-semibold">You're on Plus</h2>
          <p className="text-muted mt-1">
            {isLifetime ? 'Lifetime access. Thank you!' : expiresAt ? `Renews or ends on ${formatDate(expiresAt)}.` : ''}
          </p>
          {manageUrl && (
            <Button variant="secondary" icon={ExternalLink} className="mt-5" onClick={() => void openExternal(manageUrl)}>
              Manage subscription
            </Button>
          )}
        </Card>
      </>
    );
  }

  const priceFor = (kind: PlanKind) => options?.find((o) => o.kind === kind)?.price ?? FALLBACK_PRICES[kind];
  const kinds: PlanKind[] = options?.length ? options.map((o) => o.kind) : ['annual', 'monthly', 'lifetime'];
  const storeName = platform === 'ios' ? 'App Store' : platform === 'android' ? 'Google Play' : 'your account';

  return (
    <>
      <PageHeader title="Homefolio Plus" description="More room for your home, and no sponsored cards." />
      {reason && (
        <p className="bg-brand-50 text-brand-800 dark:bg-brand-900/40 dark:text-brand-200 mb-5 rounded-2xl px-4 py-3 text-sm">
          {reason}
        </p>
      )}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <h2 className="font-semibold">What you get</h2>
          <ul className="mt-3 space-y-2.5">
            {BENEFITS.map((b) => (
              <li key={b} className="flex items-start gap-2.5 text-sm">
                <Check className="text-brand-fg mt-0.5 size-4 shrink-0" aria-hidden />
                {b}
              </li>
            ))}
          </ul>
          <p className="text-muted mt-4 text-sm">Everything in the free plan stays free.</p>
        </Card>

        <Card className="p-5">
          {isDesktop ? (
            <div className="space-y-4">
              <p className="text-sm">
                Upgrade in your browser, signed in with the same account. Plus switches on here automatically when you come back.
              </p>
              <Button size="lg" icon={ExternalLink} className="w-full" onClick={() => void openExternal(`${SITE_URL}/upgrade`)}>
                Upgrade in your browser
              </Button>
            </div>
          ) : (
            <>
              <div role="radiogroup" aria-label="Choose a plan" className="space-y-2">
                {!options && canBuy
                  ? [0, 1, 2].map((i) => <Skeleton key={i} className="h-16" />)
                  : kinds.map((kind) => (
                      <button
                        key={kind}
                        type="button"
                        role="radio"
                        aria-checked={selected === kind}
                        onClick={() => setSelected(kind)}
                        className={cn(
                          'flex w-full items-center justify-between rounded-xl border p-4 text-left transition-colors',
                          selected === kind
                            ? 'border-brand-500 bg-brand-50 dark:bg-brand-900/30'
                            : 'border-line hover:bg-surface-muted',
                        )}
                      >
                        <span>
                          <span className="block font-medium">{LABELS[kind].title}</span>
                          {LABELS[kind].note && <span className="text-muted block text-xs">{LABELS[kind].note}</span>}
                        </span>
                        <span className="text-right">
                          <span className="block font-semibold">{priceFor(kind)}</span>
                          <span className="text-muted block text-xs">{LABELS[kind].period}</span>
                        </span>
                      </button>
                    ))}
              </div>
              <FormError message={error} />
              {canBuy ? (
                <Button size="lg" className="mt-4 w-full" loading={busy} disabled={!options?.length} onClick={buy}>
                  {selected === 'lifetime' ? 'Buy Plus Lifetime' : 'Subscribe to Plus'}
                </Button>
              ) : (
                <p className="bg-surface-muted text-muted mt-4 rounded-xl px-3 py-2.5 text-sm">
                  Purchases aren't available in this version. Prices shown are the planned launch prices.
                </p>
              )}
              {(platform === 'ios' || platform === 'android') && canBuy && (
                <Button variant="ghost" icon={RotateCcw} className="mt-2 w-full" onClick={restore} disabled={busy}>
                  Restore purchases
                </Button>
              )}
              <p className="text-muted mt-4 text-xs leading-relaxed">
                Subscriptions renew automatically at the same price until cancelled. Cancel any time in {storeName} settings at
                least 24 hours before renewal. Lifetime is a one-off payment. By upgrading you agree to the{' '}
                <a
                  className="underline"
                  href={`${WEBSITE_URL}/terms`}
                  onClick={(e) => {
                    e.preventDefault();
                    void openExternal(`${WEBSITE_URL}/terms`);
                  }}
                >
                  Terms of Use
                </a>{' '}
                and{' '}
                <a
                  className="underline"
                  href={`${WEBSITE_URL}/privacy`}
                  onClick={(e) => {
                    e.preventDefault();
                    void openExternal(`${WEBSITE_URL}/privacy`);
                  }}
                >
                  Privacy Policy
                </a>
                .
              </p>
            </>
          )}
        </Card>
      </div>
      <div className="mt-6 text-center">
        <LinkButton to="/" variant="ghost">
          Not now
        </LinkButton>
      </div>
    </>
  );
}
