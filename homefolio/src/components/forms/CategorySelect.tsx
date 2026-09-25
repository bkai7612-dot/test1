import { Check, X } from 'lucide-react';
import { useState } from 'react';
import { useCategories } from '@/context/CategoriesContext';
import { friendlyError } from '@/lib/errors';
import type { CategoryKind } from '@/lib/types';
import { IconButton } from '../ui/Button';
import { Input, Select } from '../ui/Field';

const ADD_NEW = '__add_new__';

interface CategorySelectProps {
  id: string;
  kind: CategoryKind;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  required?: boolean;
  'aria-invalid'?: boolean;
  'aria-describedby'?: string;
}

/** Built-in + custom categories, with an inline "add your own" option. */
export function CategorySelect({ kind, value, onChange, placeholder = 'Choose…', ...rest }: CategorySelectProps) {
  const { optionsFor, add } = useCategories();
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const options = optionsFor(kind);
  // Keep a value that is no longer in the list (e.g. a deleted custom category) selectable.
  const all = value && !options.includes(value) ? [value, ...options] : options;

  const save = async () => {
    if (!draft.trim()) return;
    setSaving(true);
    setError(null);
    try {
      const name = await add(kind, draft);
      onChange(name);
      setAdding(false);
      setDraft('');
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setSaving(false);
    }
  };

  if (adding) {
    return (
      <div>
        <div className="flex gap-2">
          <Input
            id={rest.id}
            autoFocus
            value={draft}
            maxLength={60}
            placeholder="New category name"
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                void save();
              }
            }}
          />
          <IconButton icon={Check} label="Save category" onClick={save} disabled={saving || !draft.trim()} />
          <IconButton icon={X} label="Cancel" onClick={() => setAdding(false)} />
        </div>
        {error && <p className="mt-1.5 text-sm text-rose-600">{error}</p>}
      </div>
    );
  }

  return (
    <Select
      {...rest}
      value={value}
      onChange={(e) => {
        if (e.target.value === ADD_NEW) setAdding(true);
        else onChange(e.target.value);
      }}
    >
      <option value="">{placeholder}</option>
      {all.map((o) => (
        <option key={o} value={o}>
          {o}
        </option>
      ))}
      <option value={ADD_NEW}>＋ Add your own…</option>
    </Select>
  );
}
