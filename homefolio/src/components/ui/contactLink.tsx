import { telHref } from '@/lib/format';

/** A tappable phone/email/web link, or null when there's no value (so DetailList skips it). */
export function contactLink(value: string | null, kind: 'tel' | 'email' | 'url') {
  if (!value) return null;
  const href =
    kind === 'tel'
      ? telHref(value)
      : kind === 'email'
        ? `mailto:${value}`
        : /^https?:\/\//.test(value)
          ? value
          : `https://${value}`;
  return (
    <a
      href={href}
      className="text-brand-fg font-medium hover:underline"
      {...(kind === 'url' ? { target: '_blank', rel: 'noreferrer' } : {})}
    >
      {value}
    </a>
  );
}
