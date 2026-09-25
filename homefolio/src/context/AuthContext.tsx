import type { Session, User } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { unwrap } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import { applyTheme } from '@/lib/theme';
import type { Profile } from '@/lib/types';

interface AuthState {
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  /** True after arriving from a password-reset email link. */
  recovering: boolean;
  updateProfile: (values: Partial<Profile>) => Promise<void>;
  /** Re-reads the profile, e.g. after a purchase updates the plan on the server. */
  refreshProfile: () => Promise<Profile | null>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [recovering, setRecovering] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (!data.session) setLoading(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, next) => {
      if (event === 'PASSWORD_RECOVERY') setRecovering(true);
      if (event === 'SIGNED_OUT') {
        setProfile(null);
        setRecovering(false);
      }
      setSession(next);
      if (!next) setLoading(false);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const userId = session?.user.id;

  useEffect(() => {
    if (!userId) return;
    let cancelled = false;
    // Deferred so it never runs inside the auth state callback.
    supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle()
      .then(({ data }) => {
        if (cancelled) return;
        const p = data as Profile | null;
        setProfile(p);
        if (p) applyTheme(p.theme);
        setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  const updateProfile = useCallback(
    async (values: Partial<Profile>) => {
      if (!userId) return;
      const updated = unwrap(await supabase.from('profiles').update(values).eq('id', userId).select().single()) as Profile;
      setProfile(updated);
      if (values.theme) applyTheme(values.theme);
    },
    [userId],
  );

  const refreshProfile = useCallback(async () => {
    if (!userId) return null;
    const { data } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
    const p = data as Profile | null;
    if (p) setProfile(p);
    return p;
  }, [userId]);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  const value = useMemo<AuthState>(
    () => ({ session, user: session?.user ?? null, profile, loading, recovering, updateProfile, refreshProfile, signOut }),
    [session, profile, loading, recovering, updateProfile, refreshProfile, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}

/** For pages inside the protected area, where a user is guaranteed. */
export function useUser(): User {
  const { user } = useAuth();
  if (!user) throw new Error('useUser called without a signed-in user');
  return user;
}
