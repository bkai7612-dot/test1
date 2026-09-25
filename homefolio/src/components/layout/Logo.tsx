import { Link } from 'react-router-dom';

export function LogoMark({ className = 'size-8' }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" className={className} aria-hidden>
      <rect width="32" height="32" rx="9" className="fill-brand-600" />
      <path d="M8 15.5 16 9l8 6.5V23a1 1 0 0 1-1 1h-4.5v-5h-5v5H9a1 1 0 0 1-1-1z" fill="#fff" />
    </svg>
  );
}

export function Logo({ iconOnly }: { iconOnly?: boolean }) {
  return (
    <Link to="/" className="inline-flex shrink-0 items-center gap-2.5 rounded-lg" aria-label="Homefolio home">
      <LogoMark />
      {!iconOnly && <span className="text-ink text-lg font-semibold tracking-tight">Homefolio</span>}
    </Link>
  );
}
