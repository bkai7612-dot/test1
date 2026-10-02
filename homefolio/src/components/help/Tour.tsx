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
import { cn } from '@/lib/cn';
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
  const [skipped, setSkipped] = useState<Set<number>>(new Set());
  const autoStarted = useRef(false);
  const addSkipped = useCallback((indices: number[]) => setSkipped((s) => new Set([...s, ...indices])), []);

  const start = useCallback(() => {
    navigate('/');
    setSkipped(new Set());
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
      {step !== null &&
        createPortal(
          <TourOverlay index={step} skipped={skipped} setIndex={setStep} onSkip={addSkipped} onFinish={finish} />,
          document.body,
        )}
    </TourContext.Provider>
  );
}

const GAP = 14;
const MARGIN = 16;
const CARD_W = 360;

const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(n, Math.max(lo, hi)));

/** Bottom edge of the sticky top bar, so scrolled targets never sit underneath it. */
function topInset(): number {
  const bar = document.querySelector<HTMLElement>('[data-tour-topbar]');
  return bar ? Math.max(0, bar.getBoundingClientRect().bottom) : 0;
}

/** Fixed or sticky elements (menus, the top bar) move with the screen, so scrolling won't help. */
function isPinned(el: HTMLElement): boolean {
  for (let n: HTMLElement | null = el; n && n !== document.body; n = n.parentElement) {
    const pos = getComputedStyle(n).position;
    if (pos === 'fixed' || pos === 'sticky') return true;
  }
  return false;
}

/** Scrolls so the target and its card fit on screen together, or the target sits just under the top bar if not. */
function bringIntoView(el: HTMLElement, cardH: number) {
  if (isPinned(el)) return;
  const r = el.getBoundingClientRect();
  const top = topInset() + MARGIN;
  const room = window.innerHeight - top - MARGIN;
  const block = r.height + GAP + cardH;
  const want = block <= room ? top + (room - block) / 2 : top;
  if (Math.abs(r.top - want) > 1) window.scrollBy({ top: r.top - want, behavior: 'instant' as ScrollBehavior });
}

/** Where the card goes: beside the highlight, never on top of it unless the screen is simply too small. */
function placeCard(rect: DOMRect | null, h: number): CSSProperties {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const phone = vw < 640;
  if (!rect) {
    const top = Math.max(MARGIN, (vh - h) / 2);
    return phone ? { left: MARGIN, right: MARGIN, top } : { left: (vw - CARD_W) / 2, top, width: CARD_W };
  }
  const below = vh - rect.bottom - GAP - MARGIN;
  const above = rect.top - GAP - MARGIN;
  if (phone) {
    const x = { left: MARGIN, right: MARGIN };
    if (below >= h) return { ...x, top: rect.bottom + GAP };
    if (above >= h) return { ...x, top: rect.top - GAP - h };
    return below >= above ? { ...x, top: vh - MARGIN - h } : { ...x, top: MARGIN };
  }
  const tall = rect.height > vh * 0.5;
  const left = clamp(rect.left + rect.width / 2 - CARD_W / 2, MARGIN, vw - CARD_W - MARGIN);
  if (!tall && below >= h) return { left, top: rect.bottom + GAP, width: CARD_W };
  if (!tall && above >= h) return { left, top: rect.top - GAP - h, width: CARD_W };
  const sideTop = clamp(rect.top, MARGIN, vh - h - MARGIN);
  if (vw - rect.right - GAP - MARGIN >= CARD_W) return { left: rect.right + GAP, top: sideTop, width: CARD_W };
  if (rect.left - GAP - MARGIN >= CARD_W) return { left: rect.left - GAP - CARD_W, top: sideTop, width: CARD_W };
  return { left: vw - CARD_W - MARGIN, top: below >= above ? vh - MARGIN - h : MARGIN, width: CARD_W };
}

const sameRect = (a: DOMRect | null, b: DOMRect | null) =>
  a === b ||
  (!!a &&
    !!b &&
    Math.abs(a.top - b.top) < 0.5 &&
    Math.abs(a.left - b.left) < 0.5 &&
    Math.abs(a.width - b.width) < 0.5 &&
    Math.abs(a.height - b.height) < 0.5);

function TourOverlay({
  index,
  skipped,
  setIndex,
  onSkip,
  onFinish,
}: {
  index: number;
  skipped: Set<number>;
  setIndex: (i: number) => void;
  onSkip: (indices: number[]) => void;
  onFinish: () => void;
}) {
  const step = STEPS[index];
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const [rect, setRect] = useState<DOMRect | null>(null);
  const [shown, setShown] = useState(false);
  const [cardH, setCardH] = useState(0);
  const direction = useRef<1 | -1>(1);
  const cardRef = useRef<HTMLDivElement>(null);
  const titleId = useId();

  const go = useCallback(
    (delta: 1 | -1, alsoSkip: number[] = []) => {
      direction.current = delta;
      let next = index + delta;
      // Leaving the welcome card: drop optional Home-screen steps whose target isn't there (e.g. a finished checklist).
      const extra =
        index === 0 && delta === 1
          ? STEPS.flatMap((s, i) => (s.optional && s.route === '/' && !findTarget(s.targets) ? [i] : []))
          : [];
      const skip = new Set([...skipped, ...alsoSkip, ...extra]);
      if (extra.length || alsoSkip.length) onSkip([...extra, ...alsoSkip]);
      while (skip.has(next)) next += delta;
      if (next >= STEPS.length) onFinish();
      else if (next >= 0) setIndex(next);
    },
    [index, skipped, onSkip, onFinish, setIndex],
  );

  useEffect(() => {
    if (step.route && pathname !== step.route) navigate(step.route);
  }, [step.route, pathname, navigate]);

  // Follows the target every frame: waits for the page to settle, scrolls it into view, then
  // tracks it through late-loading content, scrolling and resizing so the highlight never drifts.
  useLayoutEffect(() => {
    setShown(false);
    setRect(null);
    if (step.route && pathname !== step.route) return;
    let raf = 0;
    let phase: 'finding' | 'settling' | 'shown' = 'finding';
    let last: DOMRect | null = null;
    let stableFrames = 0;
    let shownAt = 0;
    let heightAtShow = 0;
    const began = performance.now();
    let foundAt = 0;

    const tick = () => {
      const now = performance.now();
      const h = cardRef.current?.offsetHeight ?? 0;
      setCardH((prev) => (prev === h ? prev : h));
      if (!step.targets) {
        if (phase !== 'shown') {
          phase = 'shown';
          setShown(true);
        }
        raf = requestAnimationFrame(tick);
        return;
      }
      const target = findTarget(step.targets);
      if (!target) {
        if (phase === 'finding' && now - began > 2500) {
          if (step.optional) return go(direction.current, [index]);
          phase = 'shown';
          setShown(true); // Fall back to a centred card.
        }
        raf = requestAnimationFrame(tick);
        return;
      }
      if (phase === 'finding') {
        phase = 'settling';
        foundAt = now;
      }
      let r = target.getBoundingClientRect();
      if (phase === 'settling') {
        stableFrames = sameRect(r, last) ? stableFrames + 1 : 0;
        last = r;
        if ((stableFrames >= 8 && h > 0) || now - foundAt > 1200) {
          bringIntoView(target, h);
          r = target.getBoundingClientRect();
          phase = 'shown';
          shownAt = now;
          heightAtShow = r.height;
          setShown(true);
        }
      } else if (now - shownAt < 1500 && Math.abs(r.height - heightAtShow) > 24) {
        // Content finished loading and the section grew: re-frame it once.
        bringIntoView(target, h);
        r = target.getBoundingClientRect();
        heightAtShow = r.height;
      }
      setRect((prev) => (sameRect(prev, r) ? prev : r));
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [index, pathname]);

  useEffect(() => {
    if (shown) cardRef.current?.focus({ preventScroll: true });
  }, [shown, index]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onFinish();
      if (e.key === 'ArrowRight') go(1);
      if (e.key === 'ArrowLeft' && index > 0) go(-1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [go, index, onFinish]);

  const visible = STEPS.map((_, i) => i).filter((i) => i > 0 && !skipped.has(i));
  const number = visible.indexOf(index) + 1;
  const last = index === STEPS.length - 1;
  const hole = shown && step.targets ? rect : null;
  const pad = 6;
  return (
    <div className="fixed inset-0 z-[100]">
      {/* Blocks the app underneath while the tour is open. */}
      <div className="absolute inset-0" aria-hidden />
      {hole ? (
        <div
          aria-hidden
          data-tour-hole
          className="pointer-events-none absolute rounded-2xl ring-2 ring-white/80"
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
      <div
        ref={cardRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        className={cn(
          'border-line bg-surface text-ink absolute rounded-2xl border p-5 shadow-2xl outline-none',
          !shown && 'invisible',
        )}
        style={shown ? placeCard(hole, cardH) : { left: MARGIN, top: 0, width: Math.min(CARD_W, window.innerWidth - 32) }}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            {index === 0 && <LogoMark className="mb-3 size-10" />}
            <p className="text-brand-fg text-xs font-semibold tracking-wide uppercase">
              {index === 0 ? 'Quick tour' : `Step ${number} of ${visible.length}`}
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
    </div>
  );
}
