import { MailCheck } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';
import { FormError } from '@/components/ui/States';
import { friendlyError } from '@/lib/errors';
import { SITE_URL, supabase } from '@/lib/supabase';
import { AuthLayout, PasswordInput } from './AuthLayout';

export default function Register() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirmSent, setConfirmSent] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return setError('Please enter your email address.');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return setError('Please enter a valid email address.');
    if (password.length < 8) return setError('Please choose a password of at least 8 characters.');
    setBusy(true);
    setError(null);
    const { data, error: err } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: { data: { full_name: name.trim() }, emailRedirectTo: SITE_URL },
    });
    setBusy(false);
    if (err) return setError(friendlyError(err));
    // With email confirmation on, Supabase returns no session until the link is clicked.
    if (!data.session) setConfirmSent(true);
  };

  if (confirmSent) {
    return (
      <AuthLayout title="Check your email">
        <div className="flex flex-col items-center text-center">
          <MailCheck className="text-brand-fg size-10" aria-hidden />
          <p className="text-muted mt-3 text-sm">
            We've sent a confirmation link to <strong className="text-ink">{email}</strong>. Click it to finish setting up your
            account.
          </p>
          <Link to="/login" className="text-brand-fg mt-5 text-sm font-medium hover:underline">
            Back to log in
          </Link>
        </div>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout
      title="Create your account"
      subtitle="Everything about your home, in one place. Free."
      footer={
        <>
          Already have an account?{' '}
          <Link to="/login" className="text-brand-fg font-medium hover:underline">
            Log in
          </Link>
        </>
      }
    >
      <form onSubmit={submit} className="space-y-4" noValidate>
        <FormError message={error} />
        <Field label="Your first name" hint="So we can say hello.">
          {(a) => (
            <Input {...a} autoComplete="given-name" value={name} maxLength={80} onChange={(e) => setName(e.target.value)} />
          )}
        </Field>
        <Field label="Email" required>
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
        <Field label="Password" required hint="At least 8 characters.">
          {(a) => (
            <PasswordInput {...a} autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} />
          )}
        </Field>
        <Button type="submit" size="lg" className="w-full" loading={busy}>
          Create account
        </Button>
      </form>
    </AuthLayout>
  );
}
