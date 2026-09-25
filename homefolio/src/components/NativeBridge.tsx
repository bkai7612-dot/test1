import { Download, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { useProperties } from '@/context/PropertyContext';
import { scheduleReminders } from '@/lib/notifications';
import { isDesktop, isNative, platform } from '@/lib/platform';
import { Button } from './ui/Button';

/**
 * Glue between the web app and the phone / Windows shells. Renders nothing on
 * the website except the profile refresh when the tab regains focus.
 */
export function NativeBridge() {
  const navigate = useNavigate();
  const location = useLocation();
  const { profile, refreshProfile } = useAuth();
  const { setActive } = useProperties();
  const lastRefresh = useRef(0);

  // Re-read the plan when the app comes back to the foreground, so a purchase
  // made in the browser (Windows) or another device shows up without restarting.
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState !== 'visible' || Date.now() - lastRefresh.current < 15_000) return;
      lastRefresh.current = Date.now();
      void refreshProfile();
    };
    document.addEventListener('visibilitychange', onVisible);
    window.addEventListener('focus', onVisible);
    return () => {
      document.removeEventListener('visibilitychange', onVisible);
      window.removeEventListener('focus', onVisible);
    };
  }, [refreshProfile]);

  // Phone shells: splash screen, status bar, Android back button, notification taps.
  useEffect(() => {
    if (!isNative) return;
    const cleanups: (() => void)[] = [];
    void (async () => {
      const [{ App }, { SplashScreen }, { LocalNotifications }] = await Promise.all([
        import('@capacitor/app'),
        import('@capacitor/splash-screen'),
        import('@capacitor/local-notifications'),
      ]);
      await SplashScreen.hide();
      if (platform === 'android') {
        const back = await App.addListener('backButton', ({ canGoBack }) => {
          const dialog = document.querySelector<HTMLDialogElement>('dialog[open]');
          if (dialog) dialog.dispatchEvent(new Event('cancel', { cancelable: true }));
          else if (canGoBack) window.history.back();
          else void App.exitApp();
        });
        cleanups.push(() => void back.remove());
      }
      const tap = await LocalNotifications.addListener('localNotificationActionPerformed', ({ notification }) => {
        const extra = notification.extra as { path?: string; propertyId?: string } | undefined;
        if (extra?.propertyId) setActive(extra.propertyId);
        if (extra?.path) navigate(extra.path);
      });
      cleanups.push(() => void tap.remove());
      const resume = await App.addListener('resume', () => void refreshProfile());
      cleanups.push(() => void resume.remove());
    })();
    return () => cleanups.forEach((c) => c());
  }, [navigate, setActive, refreshProfile]);

  // Reschedule phone reminders when preferences change or the user moves around
  // the app (debounced), so new and completed tasks are picked up.
  useEffect(() => {
    if (!isNative || !profile) return;
    const t = window.setTimeout(() => void scheduleReminders(profile).catch(() => undefined), 4000);
    return () => window.clearTimeout(t);
  }, [profile, location.pathname]);

  return isDesktop ? <DesktopUpdater /> : null;
}

/** Windows app: checks for a new version on start-up and offers a one-click restart. */
function DesktopUpdater() {
  const [update, setUpdate] = useState<{ version: string; install: () => Promise<void> } | null>(null);
  const [installing, setInstalling] = useState(false);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const { check } = await import('@tauri-apps/plugin-updater');
        const found = await check();
        if (!found || cancelled) return;
        setUpdate({
          version: found.version,
          install: async () => {
            await found.downloadAndInstall();
            const { relaunch } = await import('@tauri-apps/plugin-process');
            await relaunch();
          },
        });
      } catch {
        // Offline or update server unreachable: try again next launch.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (!update || dismissed) return null;
  return (
    <div
      role="status"
      className="border-line bg-surface fixed right-4 bottom-4 z-50 flex max-w-sm items-center gap-3 rounded-2xl border p-4 shadow-lg"
    >
      <Download className="text-brand-fg size-5 shrink-0" aria-hidden />
      <p className="text-ink flex-1 text-sm">Homefolio {update.version} is ready to install.</p>
      <Button
        size="sm"
        loading={installing}
        onClick={async () => {
          setInstalling(true);
          try {
            await update.install();
          } catch {
            setInstalling(false);
          }
        }}
      >
        Restart
      </Button>
      <button
        type="button"
        onClick={() => setDismissed(true)}
        className="text-muted hover:text-ink rounded-md p-1"
        aria-label="Later"
      >
        <X className="size-4" />
      </button>
    </div>
  );
}
