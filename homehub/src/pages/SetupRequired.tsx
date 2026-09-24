import { LogoMark } from '@/components/layout/Logo';

/** Shown to developers when the Supabase environment variables are missing. */
export function SetupRequired() {
  return (
    <main className="flex min-h-dvh items-center justify-center p-6">
      <div className="border-line bg-surface max-w-md rounded-2xl border p-6">
        <LogoMark className="size-10" />
        <h1 className="mt-4 text-xl font-semibold">HomeHub needs configuring</h1>
        <p className="text-muted mt-2 text-sm">
          Copy <code className="bg-surface-muted rounded px-1">.env.example</code> to{' '}
          <code className="bg-surface-muted rounded px-1">.env.local</code> and set{' '}
          <code className="bg-surface-muted rounded px-1">VITE_SUPABASE_URL</code> and{' '}
          <code className="bg-surface-muted rounded px-1">VITE_SUPABASE_ANON_KEY</code>, then restart the dev server. See the
          README for details.
        </p>
      </div>
    </main>
  );
}
