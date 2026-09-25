import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const isSupabaseConfigured = Boolean(url && anonKey);

// A placeholder client keeps imports safe when env vars are missing; the app
// shows a setup screen instead of making requests in that case.
export const supabase = createClient(url ?? 'http://localhost:54321', anonKey ?? 'missing-key', {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});

export const STORAGE_BUCKET = 'homefolio';

/**
 * Public address of the web app. Email links (confirm sign-up, reset password)
 * always point here, because inside the phone and Windows apps the page's own
 * origin is an internal address that can't be opened from an email.
 */
export const SITE_URL = (import.meta.env.VITE_SITE_URL as string | undefined)?.replace(/\/$/, '') ?? window.location.origin;
