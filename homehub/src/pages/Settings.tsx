import { Bell, Download, Palette, KeyRound, LogOut, Sparkles, Tags, Trash2, UserRound, X, Database } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Button, IconButton } from '@/components/ui/Button';
import { Section } from '@/components/ui/Card';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { Field, Input, Select, Toggle } from '@/components/ui/Field';
import { Chips, PageHeader } from '@/components/ui/Layout';
import { FormError } from '@/components/ui/States';
import { PasswordInput } from './auth/AuthLayout';
import { useAuth, useUser } from '@/context/AuthContext';
import { useCategories } from '@/context/CategoriesContext';
import { useProperties } from '@/context/PropertyContext';
import { useToast } from '@/context/ToastContext';
import { deleteAccount, deleteProperty, type Table } from '@/lib/api';
import { friendlyError, unwrap } from '@/lib/errors';
import { titleCase } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { CategoryKind, Profile, ThemePreference } from '@/lib/types';

function AccountSection() {
  const { profile, updateProfile } = useAuth();
  const user = useUser();
  const toast = useToast();
  const [name, setName] = useState(profile?.full_name ?? '');
  const [email, setEmail] = useState(user.email ?? '');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      if (name.trim() !== (profile?.full_name ?? '')) await updateProfile({ full_name: name.trim() || null });
      if (email.trim() && email.trim() !== user.email) {
        const { error: err } = await supabase.auth.updateUser({ email: email.trim() });
        if (err) throw err;
        toast.success('Check both inboxes to confirm your new email address');
      } else {
        toast.success('Account details saved');
      }
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Section title="Account" icon={UserRound}>
      <form onSubmit={submit} className="space-y-4" noValidate>
        <FormError message={error} />
        <Field label="First name">
          {(a) => <Input {...a} value={name} maxLength={80} onChange={(e) => setName(e.target.value)} />}
        </Field>
        <Field label="Email" hint="Changing your email sends a confirmation link.">
          {(a) => <Input {...a} type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />}
        </Field>
        <Button type="submit" loading={busy}>
          Save
        </Button>
      </form>
    </Section>
  );
}

function PasswordSection() {
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
    setPassword('');
    setConfirm('');
    toast.success('Password changed');
  };

  return (
    <Section title="Password" icon={KeyRound}>
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
        <Button type="submit" loading={busy}>
          Change password
        </Button>
      </form>
    </Section>
  );
}

function PreferencesSection() {
  const { profile, updateProfile } = useAuth();
  const toast = useToast();
  const save = async (values: Partial<Profile>) => {
    try {
      await updateProfile(values);
    } catch (err) {
      toast.error(err);
    }
  };
  if (!profile) return null;
  return (
    <>
      <Section title="Appearance" icon={Palette}>
        <Chips<ThemePreference>
          label="Theme"
          value={profile.theme}
          onChange={(theme) => save({ theme })}
          options={[
            { value: 'system', label: 'Match device' },
            { value: 'light', label: 'Light' },
            { value: 'dark', label: 'Dark' },
          ]}
        />
      </Section>
      <Section title="Reminders" icon={Bell} description="Choose what appears in “Upcoming” on your dashboard.">
        <div className="space-y-3">
          <Toggle
            label="Maintenance tasks"
            checked={profile.remind_maintenance}
            onChange={(v) => save({ remind_maintenance: v })}
          />
          <Toggle label="Warranty expiry" checked={profile.remind_warranties} onChange={(v) => save({ remind_warranties: v })} />
          <Toggle label="Insurance renewals" checked={profile.remind_insurance} onChange={(v) => save({ remind_insurance: v })} />
          <Toggle label="Contract end dates" checked={profile.remind_contracts} onChange={(v) => save({ remind_contracts: v })} />
          <Field label="Look ahead">
            {(a) => (
              <Select
                {...a}
                value={profile.reminder_window_days}
                onChange={(e) => save({ reminder_window_days: Number(e.target.value) })}
              >
                {[30, 60, 90, 120, 180, 365].map((d) => (
                  <option key={d} value={d}>
                    {d === 365 ? '1 year' : `${d} days`}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        </div>
      </Section>
    </>
  );
}

function CategoriesSection() {
  const { custom, remove } = useCategories();
  const toast = useToast();
  const kinds = [...new Set(custom.map((c) => c.kind))] as CategoryKind[];
  return (
    <Section
      title="Your categories"
      icon={Tags}
      description="Categories you've added. Removing one doesn't change existing items."
    >
      {!custom.length ? (
        <p className="text-muted text-sm">You haven't added any. Choose “Add your own…” in any category list.</p>
      ) : (
        <div className="space-y-3">
          {kinds.map((k) => (
            <div key={k}>
              <p className="text-muted mb-1.5 text-xs font-medium tracking-wide uppercase">{titleCase(k)}</p>
              <ul className="flex flex-wrap gap-2">
                {custom
                  .filter((c) => c.kind === k)
                  .map((c) => (
                    <li
                      key={c.id}
                      className="border-line inline-flex items-center gap-1 rounded-full border py-0.5 pr-0.5 pl-3 text-sm"
                    >
                      {c.name}
                      <IconButton
                        icon={X}
                        label={`Remove ${c.name}`}
                        className="size-8"
                        onClick={() => remove(c.id).catch((err) => toast.error(err))}
                      />
                    </li>
                  ))}
              </ul>
            </div>
          ))}
        </div>
      )}
    </Section>
  );
}

const EXPORT_TABLES: Table[] = [
  'profiles',
  'properties',
  'rooms',
  'appliances',
  'inventory_items',
  'warranties',
  'maintenance_tasks',
  'utilities',
  'council_tax',
  'insurance_policies',
  'meter_readings',
  'household_members',
  'emergency_contacts',
  'documents',
  'photos',
  'custom_fields',
  'custom_categories',
];

function DataSection() {
  const { properties, reload, setActive } = useProperties();
  const toast = useToast();
  const [exporting, setExporting] = useState(false);
  const [creating, setCreating] = useState(false);
  const [removingSample, setRemovingSample] = useState(false);
  const samples = properties.filter((p) => p.is_sample);

  const exportData = async () => {
    setExporting(true);
    try {
      const entries = await Promise.all(EXPORT_TABLES.map(async (t) => [t, unwrap(await supabase.from(t).select('*'))] as const));
      const blob = new Blob(
        [JSON.stringify({ exported_at: new Date().toISOString(), ...Object.fromEntries(entries) }, null, 2)],
        {
          type: 'application/json',
        },
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `homehub-export-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      toast.error(err);
    } finally {
      setExporting(false);
    }
  };

  const createSample = async () => {
    setCreating(true);
    try {
      const id = unwrap(await supabase.rpc('create_sample_home')) as string;
      await reload();
      setActive(id);
      toast.success('Sample home added');
    } catch (err) {
      toast.error(err);
    } finally {
      setCreating(false);
    }
  };

  return (
    <Section title="Your data" icon={Database}>
      <div className="space-y-5">
        <div>
          <p className="text-ink text-sm font-medium">Download your data</p>
          <p className="text-muted mt-0.5 text-sm">
            A copy of all your information as a JSON file. Uploaded files can be downloaded from Documents.
          </p>
          <Button variant="secondary" size="sm" icon={Download} className="mt-2" loading={exporting} onClick={exportData}>
            Download
          </Button>
        </div>
        <div className="border-line border-t pt-5">
          <p className="text-ink text-sm font-medium">Sample home</p>
          <p className="text-muted mt-0.5 text-sm">
            A separate, clearly-labelled property filled with example data to explore HomeHub. It never mixes with your own homes.
          </p>
          {samples.length ? (
            <Button variant="secondary" size="sm" icon={Trash2} className="mt-2" onClick={() => setRemovingSample(true)}>
              Remove sample home
            </Button>
          ) : (
            <Button variant="secondary" size="sm" icon={Sparkles} className="mt-2" loading={creating} onClick={createSample}>
              Add sample home
            </Button>
          )}
        </div>
      </div>
      <ConfirmDialog
        open={removingSample}
        onClose={() => setRemovingSample(false)}
        title="Remove the sample home?"
        message="The sample property and all its example data will be deleted. Your own properties aren't affected."
        confirmLabel="Remove"
        onConfirm={async () => {
          for (const s of samples) await deleteProperty(s.id);
          await reload();
          toast.success('Sample home removed');
        }}
      />
    </Section>
  );
}

function DangerSection() {
  const { signOut } = useAuth();
  const user = useUser();
  const [deleting, setDeleting] = useState(false);
  return (
    <>
      <Section title="Log out" icon={LogOut}>
        <p className="text-muted mb-3 text-sm">Signed in as {user.email}</p>
        <Button variant="secondary" icon={LogOut} onClick={signOut}>
          Log out
        </Button>
      </Section>
      <section className="rounded-2xl border border-rose-200 p-4 sm:p-5 dark:border-rose-900/60">
        <h2 className="text-ink font-semibold">Delete account</h2>
        <p className="text-muted mt-1 text-sm">
          Permanently delete your account, every property and all documents and photos. This can't be undone.
        </p>
        <Button variant="danger" icon={Trash2} className="mt-4" onClick={() => setDeleting(true)}>
          Delete my account
        </Button>
      </section>
      <ConfirmDialog
        open={deleting}
        onClose={() => setDeleting(false)}
        title="Delete your account?"
        message="All of your properties, information, documents and photos will be permanently deleted."
        confirmText="DELETE"
        confirmLabel="Delete everything"
        onConfirm={async () => {
          await deleteAccount(user.id);
          await supabase.auth.signOut({ scope: 'local' });
        }}
      />
    </>
  );
}

export default function Settings() {
  return (
    <>
      <PageHeader title="Settings" />
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="space-y-4">
          <AccountSection />
          <PasswordSection />
          <CategoriesSection />
        </div>
        <div className="space-y-4">
          <PreferencesSection />
          <DataSection />
          <DangerSection />
        </div>
      </div>
    </>
  );
}
