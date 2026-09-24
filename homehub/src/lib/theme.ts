import type { ThemePreference } from './types';

const KEY = 'homehub-theme';
const media = typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null;
let current: ThemePreference = 'system';

function render() {
  // When embedded, a host page may pin its theme with data-theme on <html>.
  const host = document.documentElement.dataset.theme;
  const system = host === 'dark' || (host !== 'light' && Boolean(media?.matches));
  const dark = current === 'dark' || (current === 'system' && system);
  document.documentElement.classList.toggle('dark', dark);
}

media?.addEventListener('change', () => {
  if (current === 'system') render();
});

export function getStoredTheme(): ThemePreference {
  try {
    const v = localStorage.getItem(KEY);
    if (v === 'light' || v === 'dark' || v === 'system') return v;
  } catch {
    // Storage may be unavailable (private mode); fall back to system.
  }
  return 'system';
}

export function applyTheme(theme: ThemePreference): void {
  current = theme;
  try {
    localStorage.setItem(KEY, theme);
  } catch {
    // ignore
  }
  render();
}

applyTheme(getStoredTheme());
