const currency = new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'GBP' });
const longDate = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
const shortDate = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });

/** Parses a YYYY-MM-DD string as a local calendar date (no timezone shift). */
export function parseDate(value: string): Date {
  const [y, m, d] = value.slice(0, 10).split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function toISODate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function today(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

export function todayISO(): string {
  return toISODate(today());
}

/** Whole days from today to the given date (negative when in the past). */
export function daysUntil(value: string): number {
  return Math.round((parseDate(value).getTime() - today().getTime()) / 86_400_000);
}

export function formatDate(value: string | null | undefined, style: 'long' | 'short' = 'long'): string {
  if (!value) return '';
  const date = value.length > 10 ? new Date(value) : parseDate(value);
  return (style === 'long' ? longDate : shortDate).format(date);
}

export function formatMoney(value: number | null | undefined): string {
  if (value === null || value === undefined) return '';
  return currency.format(Number(value));
}

export function formatNumber(value: number | null | undefined, maxDigits = 2): string {
  if (value === null || value === undefined) return '';
  return new Intl.NumberFormat('en-GB', { maximumFractionDigits: maxDigits }).format(Number(value));
}

export function formatBytes(bytes: number | null | undefined): string {
  if (!bytes) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  const gb = bytes / (1024 * 1024 * 1024);
  return `${Number.isInteger(gb) ? gb : gb.toFixed(1)} GB`;
}

/** "in 24 days", "tomorrow", "3 days ago", "in 4 months". */
export function relativeDays(days: number): string {
  if (days === 0) return 'today';
  if (days === 1) return 'tomorrow';
  if (days === -1) return 'yesterday';
  const abs = Math.abs(days);
  let text: string;
  if (abs < 45) text = `${abs} days`;
  else if (abs < 365) text = `${Math.round(abs / 30)} months`;
  else {
    const years = Math.round(abs / 36.5) / 10;
    text = `${years} ${years === 1 ? 'year' : 'years'}`;
  }
  return days > 0 ? `in ${text}` : `${text} ago`;
}

export function greeting(date = new Date()): string {
  const h = date.getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

export function propertyAddress(p: {
  address_line1: string | null;
  address_line2?: string | null;
  town?: string | null;
  postcode: string | null;
}): string {
  return [p.address_line1, p.address_line2, p.town, p.postcode].filter(Boolean).join(', ');
}

export function titleCase(value: string): string {
  return value.replace(/[_-]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

export function labelFor(options: { value: string; label: string }[], value: string | null | undefined): string {
  if (!value) return '';
  return options.find((o) => o.value === value)?.label ?? value;
}

export function telHref(phone: string): string {
  return `tel:${phone.replace(/[^\d+]/g, '')}`;
}
