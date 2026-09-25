import { Capacitor } from '@capacitor/core';

export type Platform = 'web' | 'ios' | 'android' | 'desktop';

/** Which build is running: the website, the phone apps (Capacitor) or the Windows app (Tauri). */
export const platform: Platform = (() => {
  if (typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window) return 'desktop';
  const native = Capacitor.getPlatform();
  if (native === 'ios' || native === 'android') return native;
  return 'web';
})();

export const isNative = platform === 'ios' || platform === 'android';
export const isDesktop = platform === 'desktop';

/** Opens a link in the device's real browser, never inside the app's window. */
export async function openExternal(url: string): Promise<void> {
  if (isDesktop) {
    const { openUrl } = await import('@tauri-apps/plugin-opener');
    await openUrl(url);
    return;
  }
  if (isNative) {
    const { Browser } = await import('@capacitor/browser');
    await Browser.open({ url });
    return;
  }
  window.open(url, '_blank', 'noopener,noreferrer');
}

export const SUPPORT_EMAIL = import.meta.env.VITE_SUPPORT_EMAIL ?? 'support@homefolio.co.uk';

/** The marketing website (terms, privacy, support). */
export const WEBSITE_URL = (import.meta.env.VITE_WEBSITE_URL ?? 'https://homefolio.co.uk').replace(/\/$/, '');
