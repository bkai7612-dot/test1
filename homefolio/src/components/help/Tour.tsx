import { ArrowLeft, ArrowRight, X } from 'lucide-react';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { createPortal } from 'react-dom';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { useProperties } from '@/context/PropertyContext';
import { Button } from '../ui/Button';
import { LogoMark } from '../layout/Logo';

interface TourStep {
  /** Page to show first. */
  route?: string;
  /** data-tour names to highlight, first visible wins. None = a centred card. */
  targets?: string[];
  /** Skip the step when its target isn't on screen (e.g. the checklist once it's complete). */
  optional?: boolean;
  title: string;
  body: string;
}

const STEPS: TourStep[] = [
  {
    route: '/',
    title: 'Welcome to Homefolio',
    body: 'Here is a one-minute tour of the app. You can skip it at any time and replay it from Help.',
  },
  {
    route: '/',
    targets: ['property-card'],
    title: 'Your home',
    body: 'This is the home you are looking at. Tap it to see and edit its profile: address, bedrooms, bin day, Wi-Fi name and more.',
  },
  {
    route: '/',
    targets: ['switcher'],
    optional: true,
    title: 'Switch homes',
    body: 'Got more than one property? Tap here to switch between them. Everything you see belongs to the home shown here.',
  },
  {
    route: '/',
    targets: ['checklist'],
    optional: true,
    title: 'Your first steps',
    body: 'Follow this checklist to set up your home. Each line takes you straight to the right place, and ticks itself off when done.',
  },
  {
    route: '/',
    targets: ['quick-actions'],
    title: 'Add things fast',
    body: 'Add an appliance, a document, a maintenance task or a room in one tap.',
  },
  {
    route: '/',
    targets: ['upcoming'],
    title: 'What is coming up',
    body: 'Maintenance that is due, warranties about to expire, insurance renewals and contracts ending — all in one list, soonest first.',
  },
  {
    route: '/',
    targets: ['search'],
    title: 'Find anything',
    body: 'Search every appliance, document, task and contact at once. Try a brand name like "Samsung" or a word like "boiler".',
  },
  {
    route: '/',
    targets: ['nav'],
    title: 'Every section',
    body: 'Rooms, appliances, documents, bills, insurance, meter readings, household and emergency numbers all live here. On a phone, tap More for the rest.',
  },
  {
    route: '/maintenance',
    targets: ['page-actions'],
    title: 'Maintenance reminders',
    body: 'Tap Add task for jobs like a boiler service. Choose how often it repeats, and tick it off when it is done — the next one is scheduled for you.',
  },
  {
    route: '/appliances',
    targets: ['page-actions'],
    title: 'Appliances and warranties',
    body: 'Add your appliances with their model and serial numbers. Open one to add its warranty, receipt, manual and photos.',
  },
  {
    route: '/documents',
    targets: ['page-actions'],
    title: 'Receipts and documents',
    body: 'Upload receipts, manuals, certificates and policies. On a phone you can take a photo of a paper receipt.',
  },
  {
    route: '/documents',
    targets: ['page-help'],
    title: 'Help on every page',
    body: 'Not sure what to do? Tap "How it works" on any page for simple step-by-step instructions.',
  },
  {
    route: '/',
    title: 'You are all set',
    body: 'Start with the Getting started checklist on your Home screen. You can replay this tour any time from Help.',
  },
];

interface TourState {
  start: () => void;
}

const TourContext = createContext<TourState>({ start: () => {} });
export const useTour = () => useContext(TourContext);

function findTarget(names: string[] | undefined): HTMLElement | null {
  for (const name of names ?? []) {
    for (const el of document.querySelectorAll<HTMLElement>(`[data-tour="${name}"]`)) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) return el;
    }
  }
  return null;
}

export function TourProvider({ children }: { children: ReactNode }) {
  const { profile, updateProfile } = useAuth();
  const { active } = useProperties();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const [step, setStep] = useState<number | null>(null);
  const autoStarted = useRef(false);

  const start = useCallback(() => {
    navigate('/');
    setStep(0);
  }, [navigate]);

  // Shows once per account, the first time the Home screen has a property on it.
  useEffect(() => {
    if (autoStarted.current || !profile || profile.tour_completed_at || !active || pathname !== '/') return;
    autoStarted.current = true;
    setStep(0);
  }, [profile, active, pathname]);

  const finish = useCallback(() => {
    setStep(null);
    navigate('/');
    if (!profile?.tour_completed_at) void updateProfile({ tour_completed_at: new Date().toISOString() }).catch(() => {});
  }, [navigate, profile?.tour_completed_at, updateProfile]);

  return (
    <TourContext.Provider value={{ start }}>
      {children}
      {step !== null && createPortal(<TourOverlay index={step} setIndex={setStep} onFinish={finish} />, document.body)}
    </TourContext.Provider>
  );
}

interface Placement {
  hole: DOMRect | null;
  card: CSSProperties;
}

function place(rect: DOMRect | null): Placement {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const gap = 14;
  if (!rect)
    return {
      hole: null,
      card:
        vw < 640
          ? { left: 16, right: 16, top: '50%', transform: 'translateY(-50%)' }
          : { left: '50%', top: '50%', transform: 'translate(-50%, -50%)', width: 360 },
    };
  // Phones: dock the card on the half of the screen away from the highlight.
  if (vw < 640) {
    const inTopHalf = rect.top + rect.height / 2 < vh / 2;
    return { hole: rect, card: inTopHalf ? { left: 16, right: 16, bottom: 16 } : { left: 16, right: 16, top: 16 } };
  }
  const width = 360;
  // Tall targets (the sidebar): sit beside them.
  if (rect.height > vh * 0.5) {
    const left = rect.right + gap + width < vw ? rect.right + gap : Math.max(16, rect.left - gap - width);
    return { hole: rect, card: { left, top: Math.max(16, Math.min(rect.top + 40, vh - 300)), width } };
  }
  const left = Math.max(16, Math.min(rect.left + rect.width / 2 - width / 2, vw - width - 16));
  const below = vh - rect.bottom > 240 || rect.top < 240;
  return {
    hole: rect,
    card: below ? { left, top: rect.bottom + gap, width } : { left, bottom: vh - rect.top + gap, width },
  };
}

function TourOverlay({ index, setIndex, onFinish }: { index: number; setIndex: (i: number) => void; onFinish: () => void }) {
  const step = STEPS[index];
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const [placement, setPlacement] = useState<Placement | null>(null);
  const [direction, setDirection] = useState<1 | -1>(1);
  const cardRef = useRef<HTMLDivElement>(null);
  const titleId = useId();
  const last = index === STEPS.length - 1;

  const go = useCallback(
    (delta: 1 | -1) => {
      setDirection(delta);
      const nextIndex = index + delta;
      if (nextIndex >= STEPS.length) onFinish();
      else if (nextIndex >= 0) setIndex(nextIndex);
    },
    [index, onFinish, setIndex],
  );

  useEffect(() => {
    if (step.route && pathname !== step.route) navigate(step.route);
  }, [step.route, pathname, navigate]);

  // Wait for the page (and its target) to render, then measure. Re-measure on scroll/resize.
  useLayoutEffect(() => {
    setPlacement(null);
    if (step.route && pathname !== step.route) return;
    let target: HTMLElement | null = null;
    let raf = 0;
    let cancelled = false;
    const began = performance.now();
    const measure = () => setPlacement(place(target ? target.getBoundingClientRect() : null));
    const look = () => {
      if (cancelled) return;
      target = findTarget(step.targets);
      if (!step.targets || target) {
        target?.scrollIntoView({ block: 'center', inline: 'nearest' });
        measure();
        return;
      }
      if (performance.now() - began < 2500) raf = requestAnimationFrame(look);
      else if (step.optional) go(direction);
      else measure();
    };
    look();
    window.addEventListener('resize', measure);
    window.addEventListener('scroll', measure, true);
    return () => {
      cancelled = true;
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', measure);
      window.removeEventListener('scroll', measure, true);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [index, pathname]);

  useEffect(() => {
    if (placement) cardRef.current?.focus();
  }, [placement, index]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onFinish();
      if (e.key === 'ArrowRight') go(1);
      if (e.key === 'ArrowLeft' && index > 0) go(-1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [go, index, onFinish]);

  const hole = placement?.hole;
  const pad = 6;
  return (
    <div className="fixed inset-0 z-[100]">
      {/* Blocks the app underneath while the tour is open. */}
      <div className="absolute inset-0" aria-hidden />
      {hole ? (
        <div
          aria-hidden
          className="pointer-events-none absolute rounded-2xl ring-2 ring-white/80 motion-safe:transition-all motion-safe:duration-200"
          style={{
            left: hole.left - pad,
            top: hole.top - pad,
            width: hole.width + pad * 2,
            height: hole.height + pad * 2,
            boxShadow: '0 0 0 9999px rgba(15, 23, 42, 0.62)',
          }}
        />
      ) : (
        <div aria-hidden className="absolute inset-0 bg-slate-900/60" />
      )}
      {placement && (
        <div
          ref={cardRef}
          role="dialog"
          aria-modal="true"
          aria-labelledby={titleId}
          tabIndex={-1}
          className="border-line bg-surface text-ink absolute w-auto max-w-[calc(100vw-32px)] rounded-2xl border p-5 shadow-2xl outline-none sm:w-[360px]"
          style={placement.card}
        >
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              {index === 0 && <LogoMark className="mb-3 size-10" />}
              <p className="text-brand-fg text-xs font-semibold tracking-wide uppercase">
                {index === 0 ? 'Quick tour' : `Step ${index} of ${STEPS.length - 1}`}
              </p>
              <h2 id={titleId} className="mt-1 text-lg font-semibold">
                {step.title}
              </h2>
            </div>
            <button
              type="button"
              onClick={onFinish}
              aria-label="Close the tour"
              className="text-muted hover:bg-surface-muted hover:text-ink -mt-1 -mr-2 inline-flex size-10 shrink-0 items-center justify-center rounded-xl"
            >
              <X className="size-5" aria-hidden />
            </button>
          </div>
          <p className="text-muted mt-2 text-sm leading-relaxed">{step.body}</p>
          <div className="mt-5 flex items-center justify-between gap-2">
            {index === 0 ? (
              <Button variant="ghost" size="sm" onClick={onFinish}>
                Skip tour
              </Button>
            ) : (
              <Button variant="ghost" size="sm" icon={ArrowLeft} onClick={() => go(-1)}>
                Back
              </Button>
            )}
            <Button size="sm" onClick={() => go(1)}>
              {index === 0 ? 'Start the tour' : last ? 'Finish' : 'Next'}
              {!last && <ArrowRight className="size-4" aria-hidden />}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
