import { useState } from 'react';
import { formatDate, formatNumber } from '@/lib/format';

export interface UsagePoint {
  /** Date of the later reading. */
  date: string;
  from: string;
  usage: number;
}

const W = 640;
const H = 220;
const PAD = { top: 16, right: 12, bottom: 28, left: 48 };

function niceMax(v: number): number {
  if (v <= 0) return 1;
  const mag = 10 ** Math.floor(Math.log10(v));
  const n = v / mag;
  return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * mag;
}

/**
 * Single-series bar chart of usage between consecutive readings.
 * One series, so no legend — the section title names it. Hover/tap shows values.
 */
export function MeterChart({ points, unit, label }: { points: UsagePoint[]; unit: string; label: string }) {
  const [active, setActive] = useState<number | null>(null);
  const max = niceMax(Math.max(...points.map((p) => p.usage)));
  const plotW = W - PAD.left - PAD.right;
  const plotH = H - PAD.top - PAD.bottom;
  const slot = plotW / points.length;
  const barW = Math.max(4, Math.min(40, slot - 2));
  const ticks = [0, max / 2, max];
  const y = (v: number) => PAD.top + plotH - (v / max) * plotH;
  const labelEvery = Math.ceil(points.length / 6);
  const hovered = active !== null ? points[active] : null;

  return (
    <figure className="relative">
      <svg
        viewBox={`0 0 ${W} ${H}`}
        className="h-auto w-full"
        role="img"
        aria-label={`${label} usage between readings, ${points.length} periods. Values are listed below.`}
        onMouseLeave={() => setActive(null)}
      >
        {ticks.map((t) => (
          <g key={t}>
            <line x1={PAD.left} x2={W - PAD.right} y1={y(t)} y2={y(t)} className="stroke-line" strokeWidth={1} />
            <text x={PAD.left - 8} y={y(t)} dy="0.32em" textAnchor="end" className="fill-muted text-[11px]">
              {formatNumber(t, 0)}
            </text>
          </g>
        ))}
        {points.map((p, i) => {
          const x = PAD.left + i * slot + (slot - barW) / 2;
          const top = y(p.usage);
          const h = Math.max(0, PAD.top + plotH - top);
          const r = Math.min(4, barW / 2, h);
          // Rounded data end at the top, square at the baseline.
          const d = `M${x},${PAD.top + plotH} V${top + r} Q${x},${top} ${x + r},${top} H${x + barW - r} Q${x + barW},${top} ${x + barW},${top + r} V${PAD.top + plotH} Z`;
          return (
            <g key={p.date}>
              <path
                d={d}
                className={active === i ? 'fill-brand-700 dark:fill-brand-300' : 'fill-brand-500 dark:fill-brand-400'}
              />
              {i % labelEvery === 0 && (
                <text x={x + barW / 2} y={H - 8} textAnchor="middle" className="fill-muted text-[11px]">
                  {formatDate(p.date, 'short').replace(/ \d{4}$/, '')}
                </text>
              )}
              {/* Hit target larger than the mark. */}
              <rect
                x={PAD.left + i * slot}
                y={PAD.top}
                width={slot}
                height={plotH}
                fill="transparent"
                onMouseEnter={() => setActive(i)}
                onClick={() => setActive(i)}
              />
            </g>
          );
        })}
      </svg>
      {hovered && (
        <div className="border-line bg-surface pointer-events-none absolute top-0 right-0 rounded-lg border px-3 py-2 text-xs shadow-md">
          <p className="text-ink font-semibold">
            {formatNumber(hovered.usage)} {unit}
          </p>
          <p className="text-muted">
            {formatDate(hovered.from, 'short')} – {formatDate(hovered.date, 'short')}
          </p>
        </div>
      )}
      <figcaption className="text-muted mt-1 text-xs">Usage between readings ({unit}). Tap a bar for details.</figcaption>
    </figure>
  );
}
