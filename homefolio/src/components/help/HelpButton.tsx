import { CircleHelp, Lightbulb } from 'lucide-react';
import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { guideForPath, type Guide } from '@/lib/guides';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';

/** The numbered steps and tips for one guide. Used in the help sheet and on the Help page. */
export function GuideSteps({ guide }: { guide: Guide }) {
  return (
    <div className="space-y-4">
      <ol className="space-y-3">
        {guide.steps.map((step, i) => (
          <li key={i} className="flex gap-3">
            <span className="bg-brand-50 text-brand-700 dark:bg-brand-900/40 dark:text-brand-300 flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold">
              {i + 1}
            </span>
            <span className="text-ink pt-1 text-sm">{step}</span>
          </li>
        ))}
      </ol>
      {guide.tips?.map((tip, i) => (
        <p key={i} className="bg-surface-muted text-ink flex gap-2.5 rounded-xl p-3 text-sm">
          <Lightbulb className="mt-0.5 size-4 shrink-0 text-amber-500" aria-hidden />
          {tip}
        </p>
      ))}
    </div>
  );
}

/** "How it works" button for the current page; opens its step-by-step guide. */
export function HelpButton() {
  const { pathname } = useLocation();
  const guide = guideForPath(pathname);
  const [open, setOpen] = useState(false);
  if (!guide) return null;
  return (
    <>
      <Button variant="ghost" size="sm" icon={CircleHelp} onClick={() => setOpen(true)} data-tour="page-help">
        How it works
      </Button>
      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title={guide.title}
        description={guide.summary}
        footer={
          <>
            <Link to="/help" onClick={() => setOpen(false)} className="text-brand-fg mr-auto self-center text-sm font-medium">
              All guides
            </Link>
            <Button onClick={() => setOpen(false)}>Got it</Button>
          </>
        }
      >
        <GuideSteps guide={guide} />
      </Modal>
    </>
  );
}
