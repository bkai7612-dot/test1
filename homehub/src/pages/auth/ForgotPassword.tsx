import { MailCheck } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';
import { FormError } from '@/components/ui/States';
import { friendlyError } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import { AuthLayout } from './AuthLayout';

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return setError('Please enter your email address.');
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    setBusy(false);
    if (err) return setError(friendlyError(err));
    setSent(true);
  };

  return (
    <AuthLayout
      title="Reset your password"
      subtitle={sent ? undefined : "Enter your email and we'll send you a reset link."}
      footer={
        <Link to="/login" className="text-brand-fg font-medium hover:underline">
          Back to log in
        </Link>
      }
    >
      {sent ? (
        <div className="flex flex-col items-center text-center">
          <MailCheck className="text-brand-fg size-10" aria-hidden />
          <p className="text-muted mt-3 text-sm">
            If an account exists for <strong className="text-ink">{email}</strong>, you'll receive an email with a link to choose
            a new password.
          </p>
        </div>
      ) : (
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
          <Button type="submit" size="lg" className="w-full" loading={busy}>
            Send reset link
          </Button>
        </form>
      )}
    </AuthLayout>
  );
}
