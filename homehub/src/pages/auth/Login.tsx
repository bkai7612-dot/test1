import { useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';
import { FormError } from '@/components/ui/States';
import { friendlyError } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import { AuthLayout, PasswordInput } from './AuthLayout';

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password) return setError('Please enter your email and password.');
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    setBusy(false);
    if (err) return setError(friendlyError(err));
    const from = (location.state as { from?: string } | null)?.from;
    navigate(from && from !== '/login' ? from : '/', { replace: true });
  };

  return (
    <AuthLayout
      title="Welcome back"
      subtitle="Log in to HomeHub"
      footer={
        <>
          New to HomeHub?{' '}
          <Link to="/register" className="text-brand-fg font-medium hover:underline">
            Create an account
          </Link>
        </>
      }
    >
      <form onSubmit={submit} className="space-y-4" noValidate>
        <FormError message={error} />
        <Field label="Email">
          {(a) => (
            <Input
              {...a}
              type="email"
              autoComplete="email"
              inputMode="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          )}
        </Field>
        <Field label="Password">
          {(a) => (
            <PasswordInput
              {...a}
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          )}
        </Field>
        <div className="flex justify-end">
          <Link to="/forgot-password" className="text-brand-fg text-sm font-medium hover:underline">
            Forgotten your password?
          </Link>
        </div>
        <Button type="submit" size="lg" className="w-full" loading={busy}>
          Log in
        </Button>
      </form>
    </AuthLayout>
  );
}
