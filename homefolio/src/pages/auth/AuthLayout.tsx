import { Eye, EyeOff } from 'lucide-react';
import { lazy, Suspense, useState, type InputHTMLAttributes, type ReactNode } from 'react';
import { LogoMark } from '@/components/layout/Logo';
import { Input } from '@/components/ui/Field';

// Prototype-only note; compiled out of the real apps.
const DemoAuthNotice = import.meta.env.VITE_DEMO
  ? lazy(() => import('@/demo/DemoControls').then((m) => ({ default: m.DemoAuthNotice })))
  : null;

export function AuthLayout({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center text-center">
          <LogoMark className="size-12" />
          <h1 className="mt-5 text-2xl font-semibold tracking-tight">{title}</h1>
          {subtitle && <p className="text-muted mt-1.5 text-sm">{subtitle}</p>}
        </div>
        {DemoAuthNotice && (
          <Suspense fallback={null}>
            <DemoAuthNotice />
          </Suspense>
        )}
        <div className="border-line bg-surface rounded-2xl border p-5 shadow-sm sm:p-6">{children}</div>
        {footer && <div className="text-muted mt-6 text-center text-sm">{footer}</div>}
      </div>
    </main>
  );
}

export function PasswordInput(props: InputHTMLAttributes<HTMLInputElement>) {
  const [visible, setVisible] = useState(false);
  return (
    <div className="relative">
      <Input {...props} type={visible ? 'text' : 'password'} className="pr-12" />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        className="text-muted hover:text-ink absolute top-1/2 right-1 flex size-10 -translate-y-1/2 items-center justify-center rounded-lg"
        aria-label={visible ? 'Hide password' : 'Show password'}
      >
        {visible ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
      </button>
    </div>
  );
}
