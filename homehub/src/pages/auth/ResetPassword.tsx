import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { FormError, Spinner } from '@/components/ui/States';
import { useAuth } from '@/context/AuthContext';
import { useToast } from '@/context/ToastContext';
import { friendlyError } from '@/lib/errors';
import { supabase } from '@/lib/supabase';
import { AuthLayout, PasswordInput } from './AuthLayout';

export default function ResetPassword() {
  const { session, loading } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (password.length < 8) return setError('Please choose a password of at least 8 characters.');
    if (password !== confirm) return setError("The passwords don't match.");
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.auth.updateUser({ password });
    setBusy(false);
    if (err) return setError(friendlyError(err));
    toast.success('Your password has been updated');
    navigate('/', { replace: true });
  };

  if (loading) return <Spinner />;

  // The reset link signs the user in; without a session the link was invalid or expired.
  if (!session) {
    return (
      <AuthLayout title="Link expired" subtitle="This password reset link is invalid or has expired.">
        <Link to="/forgot-password" className="text-brand-fg block text-center text-sm font-medium hover:underline">
          Request a new link
        </Link>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout title="Choose a new password">
      <form onSubmit={submit} className="space-y-4" noValidate>
        <FormError message={error} />
        <Field label="New password" hint="At least 8 characters.">
          {(a) => (
            <PasswordInput {...a} autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} />
          )}
        </Field>
        <Field label="Confirm new password">
          {(a) => (
            <PasswordInput {...a} autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
          )}
        </Field>
        <Button type="submit" size="lg" className="w-full" loading={busy}>
          Update password
        </Button>
      </form>
    </AuthLayout>
  );
}
