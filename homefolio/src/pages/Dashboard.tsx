import {
  Building2,
  CalendarCheck,
  ChevronRight,
  DoorOpen,
  FilePlus,
  FileText,
  Package,
  Plus,
  ShieldCheck,
  Sparkles,
  Umbrella,
  WashingMachine,
  Wrench,
  Zap,
  type LucideIcon,
} from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { LogoMark } from '@/components/layout/Logo';
import { StatusBadge, Tag } from '@/components/ui/Badges';
import { Button } from '@/components/ui/Button';
import { Card, Section } from '@/components/ui/Card';
import { EmptyState, ErrorState, Skeleton } from '@/components/ui/States';
import { useAuth } from '@/context/AuthContext';
import { useProperties } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { useQuery } from '@/hooks/useQuery';
import { unwrap } from '@/lib/errors';
import { daysUntil, formatDate, greeting, propertyAddress, relativeDays } from '@/lib/format';
import type { Status } from '@/lib/status';
import { supabase } from '@/lib/supabase';
import type { Property, PropertySummary, Reminder, ReminderKind } from '@/lib/types';
import { PropertyFormModal } from './Properties';
import { SponsoredCard } from '@/components/SponsoredCard';
import { GettingStarted } from '@/components/help/GettingStarted';
import { HelpButton } from '@/components/help/HelpButton';

const REMINDER_ICONS: Record<ReminderKind, LucideIcon> = {
  maintenance: Wrench,
  warranty: ShieldCheck,
  insurance: Umbrella,
  contract: Zap,
};

function reminderLink(r: Reminder): string {
  switch (r.kind) {
    case 'maintenance':
      return `/maintenance/${r.item_id}`;
    case 'warranty':
      return r.detail === 'inventory' ? `/inventory/${r.item_id}` : `/appliances/${r.item_id}`;
    case 'insurance':
      return `/insurance/${r.item_id}`;
    case 'contract':
      return `/utilities/${r.item_id}`;
  }
}

function reminderText(r: Reminder): { text: string; status: Status } {
  const days = daysUntil(r.due_date);
  const rel = relativeDays(days);
  switch (r.kind) {
    case 'maintenance':
      if (days < 0) return { text: `Overdue by ${rel.replace(' ago', '')}`, status: 'overdue' };
      if (days === 0) return { text: 'Due today', status: 'due' };
      return { text: `Due ${rel}`, status: days <= 7 ? 'due' : 'upcoming' };
    case 'warranty':
      return { text: `Expires ${rel}`, status: days <= 60 ? 'expiring' : 'active' };
    case 'insurance':
      return { text: `Renews ${rel}`, status: days <= 30 ? 'due' : 'upcoming' };
    case 'contract':
      return { text: `Contract ends ${rel}`, status: days <= 30 ? 'due' : 'upcoming' };
  }
}

const QUICK_ACTIONS: { to: string; label: string; icon: LucideIcon }[] = [
  { to: '/appliances?new=1', label: 'Add appliance', icon: WashingMachine },
  { to: '/documents?new=1', label: 'Add document', icon: FilePlus },
  { to: '/maintenance?new=1', label: 'Add maintenance', icon: CalendarCheck },
  { to: '/rooms?new=1', label: 'Add room', icon: DoorOpen },
];

export default function Dashboard() {
  const { profile } = useAuth();
  const { active, loading, error, reload } = useProperties();

  if (loading) return <DashboardSkeleton />;
  if (error && !active) return <ErrorState error={error} onRetry={reload} />;
  if (!active) return <Welcome />;

  const name = profile?.full_name?.split(' ')[0];
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-muted text-sm font-medium tracking-wide uppercase">Welcome back</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">
            {greeting()}
            {name ? `, ${name}` : ''}
          </h1>
        </div>
        <HelpButton />
      </div>
      <PropertyCard property={active} />
      <GettingStarted propertyId={active.id} />
      <QuickActions />
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-5">
        <div className="min-w-0 lg:col-span-3" data-tour="upcoming">
          <Upcoming propertyId={active.id} />
        </div>
        <div className="min-w-0 lg:col-span-2">
          <Summary propertyId={active.id} />
        </div>
      </div>
      <SponsoredCard placement="dashboard" />
    </div>
  );
}

function PropertyCard({ property }: { property: Property }) {
  return (
    <Link
      to={`/properties/${property.id}`}
      data-tour="property-card"
      className="border-line bg-surface hover:border-brand-300 flex items-center gap-4 rounded-2xl border p-4 transition-colors sm:p-5"
    >
      <span className="bg-brand-600 flex size-12 shrink-0 items-center justify-center rounded-xl text-white">
        <Building2 className="size-6" aria-hidden />
      </span>
      <span className="min-w-0 flex-1">
        <span className="text-muted text-xs font-medium tracking-wide uppercase">Property</span>
        <span className="flex items-center gap-2">
          <span className="text-ink truncate text-lg font-semibold">{property.name}</span>
          {property.is_sample && <Tag>Sample</Tag>}
        </span>
        <span className="text-muted block truncate text-sm">{propertyAddress(property) || 'Add an address'}</span>
      </span>
      <ChevronRight className="text-muted size-5 shrink-0" aria-hidden />
    </Link>
  );
}

function QuickActions() {
  return (
    <section aria-labelledby="quick-actions" data-tour="quick-actions">
      <h2 id="quick-actions" className="text-muted mb-3 text-sm font-semibold tracking-wide uppercase">
        Quick actions
      </h2>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {QUICK_ACTIONS.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className="border-line bg-surface text-ink hover:border-brand-300 hover:bg-surface-muted/50 flex min-h-14 items-center gap-3 rounded-2xl border px-3.5 py-3 text-sm font-medium transition-colors"
          >
            <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-9 shrink-0 items-center justify-center rounded-lg">
              <Icon className="size-[18px]" aria-hidden />
            </span>
            {label}
          </Link>
        ))}
      </div>
    </section>
  );
}

function Upcoming({ propertyId }: { propertyId: string }) {
  const { profile } = useAuth();
  const days = profile?.reminder_window_days ?? 120;
  const { data, loading, error, reload } = useQuery(
    async () => unwrap(await supabase.rpc('upcoming_reminders', { p_property_id: propertyId, p_days: days })) as Reminder[],
    [propertyId, days],
  );

  const enabled: Record<ReminderKind, boolean> = {
    maintenance: profile?.remind_maintenance ?? true,
    warranty: profile?.remind_warranties ?? true,
    insurance: profile?.remind_insurance ?? true,
    contract: profile?.remind_contracts ?? true,
  };
  const items = (data ?? []).filter((r) => enabled[r.kind]);
  const [showAll, setShowAll] = useState(false);
  const visible = showAll ? items : items.slice(0, 6);

  return (
    <Section title="Upcoming" icon={CalendarCheck} description={`The next ${days} days`}>
      {loading && !data ? (
        <div className="space-y-3">
          <Skeleton className="h-14" />
          <Skeleton className="h-14" />
          <Skeleton className="h-14" />
        </div>
      ) : error ? (
        <ErrorState error={error} onRetry={reload} />
      ) : items.length === 0 ? (
        <EmptyState
          compact
          icon={Sparkles}
          title="Nothing coming up"
          description="Maintenance, warranty expiries, insurance renewals and contract end dates will appear here."
        />
      ) : (
        <>
          <ul className="divide-line -mx-2 divide-y">
            {visible.map((r) => {
              const Icon = REMINDER_ICONS[r.kind];
              const { text, status } = reminderText(r);
              return (
                <li key={`${r.kind}-${r.item_id}-${r.due_date}`}>
                  <Link to={reminderLink(r)} className="hover:bg-surface-muted/60 flex items-center gap-3 rounded-xl px-2 py-3">
                    <span className="bg-surface-muted text-muted flex size-10 shrink-0 items-center justify-center rounded-xl">
                      <Icon className="size-5" aria-hidden />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="text-ink block truncate font-medium">{r.title}</span>
                      <span className="text-muted block truncate text-sm">
                        {text} · {formatDate(r.due_date, 'short')}
                      </span>
                    </span>
                    <span className="hidden sm:block">
                      <StatusBadge status={status} />
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
          {items.length > 6 && (
            <Button variant="ghost" size="sm" className="mt-2 w-full" onClick={() => setShowAll((s) => !s)}>
              {showAll ? 'Show less' : `Show all ${items.length}`}
            </Button>
          )}
        </>
      )}
    </Section>
  );
}

function Summary({ propertyId }: { propertyId: string }) {
  const { data, loading } = useQuery(
    async () => unwrap(await supabase.rpc('property_summary', { p_property_id: propertyId })) as PropertySummary,
    [propertyId],
  );
  const tiles: { label: string; value?: number; to: string; icon: LucideIcon; note?: string }[] = [
    { label: 'Appliances', value: data?.appliances, to: '/appliances', icon: WashingMachine },
    { label: 'Rooms', value: data?.rooms, to: '/rooms', icon: DoorOpen },
    { label: 'Documents', value: data?.documents, to: '/documents', icon: FileText },
    {
      label: 'Open tasks',
      value: data?.open_tasks,
      to: '/maintenance',
      icon: Wrench,
      note: data?.overdue_tasks ? `${data.overdue_tasks} overdue` : undefined,
    },
    { label: 'Inventory items', value: data?.inventory, to: '/inventory', icon: Package },
    { label: 'Active warranties', value: data?.active_warranties, to: '/warranties', icon: ShieldCheck },
  ];
  return (
    <Section title="Home summary" icon={Building2}>
      <ul className="grid grid-cols-2 gap-3">
        {tiles.map(({ label, value, to, icon: Icon, note }) => (
          <li key={label}>
            <Link to={to} className="bg-surface-muted/70 hover:bg-surface-muted block rounded-xl p-3 transition-colors">
              <Icon className="text-muted size-4" aria-hidden />
              {loading && !data ? (
                <Skeleton className="mt-2 h-7 w-10" />
              ) : (
                <p className="text-ink mt-1.5 text-2xl font-semibold tabular-nums">{value ?? 0}</p>
              )}
              <p className="text-muted text-sm">{label}</p>
              {note && <p className="mt-0.5 text-xs font-medium text-rose-700 dark:text-rose-300">{note}</p>}
            </Link>
          </li>
        ))}
      </ul>
    </Section>
  );
}

/** First-run experience: add a home or explore with sample data. */
function Welcome() {
  const { profile } = useAuth();
  const { reload, setActive } = useProperties();
  const toast = useToast();
  const [adding, setAdding] = useState(false);
  const [creatingSample, setCreatingSample] = useState(false);

  const createSample = async () => {
    setCreatingSample(true);
    try {
      const id = unwrap(await supabase.rpc('create_sample_home')) as string;
      await reload();
      setActive(id);
      toast.success('Sample home created — explore away!');
    } catch (err) {
      toast.error(err);
    } finally {
      setCreatingSample(false);
    }
  };

  const name = profile?.full_name?.split(' ')[0];
  return (
    <div className="mx-auto max-w-xl py-6 text-center sm:py-12">
      <LogoMark className="mx-auto size-14" />
      <h1 className="mt-6 text-2xl font-semibold tracking-tight sm:text-3xl">Welcome to Homefolio{name ? `, ${name}` : ''}</h1>
      <p className="text-muted mt-2">Everything about your home, in one place. Start by adding your home.</p>
      <Card className="mt-8 p-5 text-left sm:p-6">
        <ol className="text-ink space-y-3 text-sm">
          {['Add your home', 'Add rooms and appliances', 'Upload receipts and documents', 'Set up maintenance reminders'].map(
            (step, i) => (
              <li key={step} className="flex items-center gap-3">
                <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold">
                  {i + 1}
                </span>
                {step}
              </li>
            ),
          )}
        </ol>
        <Button size="lg" icon={Plus} className="mt-6 w-full" onClick={() => setAdding(true)}>
          Add your home
        </Button>
        <Button variant="ghost" className="mt-2 w-full" onClick={createSample} loading={creatingSample}>
          Or explore with a sample home first
        </Button>
      </Card>
      <PropertyFormModal open={adding} onClose={() => setAdding(false)} />
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div className="space-y-6" role="status" aria-label="Loading">
      <Skeleton className="h-12 w-64" />
      <Skeleton className="h-24" />
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-14" />
        ))}
      </div>
      <Skeleton className="h-64" />
    </div>
  );
}
