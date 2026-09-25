import { useAuth } from '@/context/AuthContext';

/** The signed-in user's plan, read from their profile (set by the payment webhook). */
export function usePlan() {
  const { profile, user } = useAuth();
  const expiresAt = profile?.plan_expires_at ?? null;
  const isPlus = profile?.plan === 'plus' && (!expiresAt || new Date(expiresAt) > new Date());
  const accountAgeDays = user?.created_at ? (Date.now() - new Date(user.created_at).getTime()) / 86_400_000 : 0;
  return {
    isPlus,
    isLifetime: isPlus && !expiresAt,
    expiresAt,
    source: profile?.plan_source ?? null,
    isAdmin: Boolean(profile?.is_admin),
    accountAgeDays,
  };
}
