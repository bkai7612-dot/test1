import { ChevronDown, Compass, Mail } from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { GuideSteps } from '@/components/help/HelpButton';
import { useTour } from '@/components/help/Tour';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { PageHeader, SearchInput } from '@/components/ui/Layout';
import { GUIDES, type Guide } from '@/lib/guides';
import { SUPPORT_EMAIL } from '@/lib/platform';

const GROUPS: Guide['group'][] = [
  'Getting started',
  'Your home',
  'Belongings',
  'Upkeep',
  'Bills & cover',
  'People',
  'Your account',
];

/** Every page's step-by-step guide in one place, plus the tour and support. */
export default function Help() {
  const { start } = useTour();
  const [q, setQ] = useState('');
  const query = q.trim().toLowerCase();
  const matches = (g: Guide) =>
    !query || [g.title, g.summary, ...g.steps, ...(g.tips ?? [])].some((t) => t.toLowerCase().includes(query));

  return (
    <>
      <PageHeader title="Help & tutorials" description="Simple, step-by-step instructions for everything in Homefolio." />
      <div className="space-y-6">
        <Card className="flex flex-col gap-4 p-4 sm:flex-row sm:items-center sm:p-5">
          <span className="bg-brand-600 flex size-12 shrink-0 items-center justify-center rounded-xl text-white">
            <Compass className="size-6" aria-hidden />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-ink font-semibold">New here? Take the tour</h2>
            <p className="text-muted text-sm">A one-minute walk through the main parts of the app.</p>
          </div>
          <Button onClick={start}>Start the tour</Button>
        </Card>

        <SearchInput value={q} onChange={setQ} placeholder="Search the guides, e.g. “warranty”" label="Search the guides" />

        {GROUPS.map((group) => {
          const guides = GUIDES.filter((g) => g.group === group && matches(g));
          if (!guides.length) return null;
          return (
            <section key={group} aria-labelledby={`help-${group}`}>
              <h2 id={`help-${group}`} className="text-muted mb-2 text-sm font-semibold tracking-wide uppercase">
                {group}
              </h2>
              <div className="space-y-2">
                {guides.map((g) => (
                  <details key={g.id} open={Boolean(query)} className="group border-line bg-surface rounded-2xl border">
                    <summary className="flex min-h-14 cursor-pointer list-none items-center gap-3 px-4 py-3 [&::-webkit-details-marker]:hidden">
                      <span className="min-w-0 flex-1">
                        <span className="text-ink block font-medium">{g.title}</span>
                        <span className="text-muted block text-sm">{g.summary}</span>
                      </span>
                      <ChevronDown
                        className="text-muted size-5 shrink-0 transition-transform group-open:rotate-180"
                        aria-hidden
                      />
                    </summary>
                    <div className="border-line border-t px-4 py-4">
                      <GuideSteps guide={g} />
                      {g.to && (
                        <Link to={g.to} className="text-brand-fg mt-4 inline-block text-sm font-medium">
                          Open this page →
                        </Link>
                      )}
                    </div>
                  </details>
                ))}
              </div>
            </section>
          );
        })}
        {GUIDES.every((g) => !matches(g)) && (
          <p className="text-muted text-sm">No guides mention “{q}”. Try another word, or email us below.</p>
        )}

        <Card className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:p-5">
          <Mail className="text-brand-fg size-6 shrink-0" aria-hidden />
          <p className="text-ink min-w-0 flex-1 text-sm">
            Still stuck? Email <span className="font-medium">{SUPPORT_EMAIL}</span> and a real person will reply.
          </p>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="text-brand-fg text-sm font-medium">
            Email support
          </a>
        </Card>
      </div>
    </>
  );
}
