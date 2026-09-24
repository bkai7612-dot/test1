interface ErrorLike {
  message?: string;
  code?: string;
  status?: number;
  name?: string;
}

/** A user-facing error: its message is safe to show as-is. */
export class FriendlyError extends Error {}

/** Turns any thrown value into a short, human-readable message. Never exposes stack traces. */
export function friendlyError(err: unknown, fallback = 'Something went wrong. Please try again.'): string {
  if (err instanceof FriendlyError) return err.message;
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    return 'You appear to be offline. Check your connection and try again.';
  }
  const e = (err ?? {}) as ErrorLike;
  const msg = (e.message ?? '').toLowerCase();

  if (msg.includes('failed to fetch') || msg.includes('networkerror') || msg.includes('load failed')) {
    return "We couldn't reach HomeHub. Check your connection and try again.";
  }
  if (msg.includes('invalid login credentials')) return 'That email and password combination is not right.';
  if (msg.includes('email not confirmed')) return 'Please confirm your email address first — check your inbox.';
  if (msg.includes('user already registered') || msg.includes('already been registered')) {
    return 'An account with this email already exists. Try logging in instead.';
  }
  if (msg.includes('password should be') || msg.includes('weak password')) {
    return 'Please choose a stronger password (at least 8 characters).';
  }
  if (msg.includes('same_password') || msg.includes('different from the old password')) {
    return 'Your new password must be different from your current one.';
  }
  if (msg.includes('rate limit') || e.status === 429) return 'Too many attempts. Please wait a moment and try again.';
  if (msg.includes('payload too large') || msg.includes('exceeded the maximum allowed size') || e.status === 413) {
    return 'That file is too large. The maximum size is 20 MB.';
  }
  if (msg.includes('mime type') || msg.includes('invalid_mime_type')) return "That file type isn't supported.";
  if (msg.includes('jwt') || msg.includes('not authenticated') || e.status === 401) {
    return 'Your session has expired. Please log in again.';
  }
  if (msg.includes('row-level security') || e.code === '42501') {
    return "You don't have permission to do that.";
  }
  if (e.code === '23505') return 'That already exists.';
  if (e.code === '23514' || e.code === '22P02' || e.code === '22007' || e.code === '22003') {
    return 'Some of the details are not valid. Please check the form.';
  }
  if (e.code === 'P0001' && e.message) return e.message;
  return fallback;
}

/** Throws the Supabase error (if any) and returns the data. */
export function unwrap<T>(result: { data: T; error: unknown }): T {
  if (result.error) throw result.error;
  return result.data;
}
