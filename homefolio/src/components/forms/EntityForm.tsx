import { Fragment, useState, type FormEvent, type ReactNode } from 'react';
import type { Option } from '@/lib/constants';
import { friendlyError } from '@/lib/errors';
import type { CategoryKind, Room } from '@/lib/types';
import { cn } from '@/lib/cn';
import { Button } from '../ui/Button';
import { Field, Input, Select, Textarea, Toggle } from '../ui/Field';
import { Modal } from '../ui/Modal';
import { FormError } from '../ui/States';
import { CategorySelect } from './CategorySelect';

export type FieldType =
  'text' | 'email' | 'tel' | 'url' | 'textarea' | 'number' | 'money' | 'date' | 'select' | 'category' | 'room' | 'toggle';

export type FormValues = Record<string, string | boolean>;

export interface FieldDef {
  name: string;
  label: string;
  type: FieldType;
  required?: boolean;
  placeholder?: string;
  hint?: string;
  options?: Option[];
  categoryKind?: CategoryKind;
  /** Half-width on larger screens. */
  half?: boolean;
  min?: number;
  max?: number;
  step?: string;
  maxLength?: number;
  showIf?: (values: FormValues) => boolean;
  /** Heading shown above this field to group the form. */
  section?: string;
}

export type Payload = Record<string, string | number | boolean | null>;

/** Converts a DB row into form state (null → ''). */
export function toFormValues(fields: FieldDef[], row?: object | null, defaults: FormValues = {}): FormValues {
  const values: FormValues = {};
  const source = (row ?? {}) as Record<string, unknown>;
  for (const f of fields) {
    const raw = row ? source[f.name] : undefined;
    if (f.type === 'toggle') values[f.name] = raw === undefined ? Boolean(defaults[f.name]) : Boolean(raw);
    else if (raw === null || raw === undefined) values[f.name] = (defaults[f.name] as string | undefined) ?? '';
    else values[f.name] = String(raw);
  }
  return values;
}

/** Converts form state into a DB payload ('' → null, numbers parsed). Hidden fields become null. */
export function toPayload(fields: FieldDef[], values: FormValues): Payload {
  const out: Payload = {};
  for (const f of fields) {
    const v = values[f.name];
    const visible = !f.showIf || f.showIf(values);
    if (f.type === 'toggle') out[f.name] = visible ? Boolean(v) : false;
    else if (!visible || v === '' || v === undefined) out[f.name] = null;
    else if (f.type === 'number' || f.type === 'money') out[f.name] = Number(v);
    else out[f.name] = String(v).trim() || null;
  }
  return out;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validate(fields: FieldDef[], values: FormValues): Record<string, string> {
  const errors: Record<string, string> = {};
  for (const f of fields) {
    if (f.showIf && !f.showIf(values)) continue;
    const v = values[f.name];
    if (f.type === 'toggle') continue;
    const s = String(v ?? '').trim();
    if (f.required && !s) {
      errors[f.name] = `${f.label} is required.`;
      continue;
    }
    if (!s) continue;
    if (f.type === 'email' && !EMAIL_RE.test(s)) errors[f.name] = 'Please enter a valid email address.';
    if (f.type === 'number' || f.type === 'money') {
      const n = Number(s);
      if (Number.isNaN(n)) errors[f.name] = 'Please enter a number.';
      else if (f.min !== undefined && n < f.min) errors[f.name] = `Must be ${f.min} or more.`;
      else if (f.max !== undefined && n > f.max) errors[f.name] = `Must be ${f.max} or less.`;
    }
    if (f.type === 'date' && !/^\d{4}-\d{2}-\d{2}$/.test(s)) errors[f.name] = 'Please enter a valid date.';
  }
  return errors;
}

interface EntityFormProps {
  id: string;
  fields: FieldDef[];
  initial: FormValues;
  rooms?: Room[];
  onSubmit: (payload: Payload, values: FormValues) => Promise<void>;
  /** Extra cross-field validation. */
  extraValidate?: (values: FormValues) => Partial<Record<string, string>>;
  children?: ReactNode;
  onBusyChange?: (busy: boolean) => void;
}

export function EntityForm({ id, fields, initial, rooms, onSubmit, extraValidate, children, onBusyChange }: EntityFormProps) {
  const [values, setValues] = useState<FormValues>(initial);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);

  const set = (name: string, value: string | boolean) => {
    setValues((v) => ({ ...v, [name]: value }));
    if (errors[name]) setErrors((e) => ({ ...e, [name]: '' }));
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const found = { ...validate(fields, values), ...(extraValidate?.(values) ?? {}) } as Record<string, string>;
    const hasErrors = Object.values(found).some(Boolean);
    setErrors(found);
    if (hasErrors) {
      setFormError('Please check the highlighted fields.');
      return;
    }
    setFormError(null);
    onBusyChange?.(true);
    try {
      await onSubmit(toPayload(fields, values), values);
    } catch (err) {
      setFormError(friendlyError(err, "We couldn't save that. Please try again."));
    } finally {
      onBusyChange?.(false);
    }
  };

  return (
    <form id={id} onSubmit={submit} noValidate className="space-y-4">
      <FormError message={formError} />
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {fields.map((f) => {
          if (f.showIf && !f.showIf(values)) return null;
          const full = !f.half;
          return (
            <Fragment key={f.name}>
              {f.section && (
                <h3 className="border-line text-ink border-t pt-4 text-sm font-semibold sm:col-span-2">{f.section}</h3>
              )}
              <div className={cn(full && 'sm:col-span-2')}>
                {f.type === 'toggle' ? (
                  <Toggle
                    label={f.label}
                    description={f.hint}
                    checked={Boolean(values[f.name])}
                    onChange={(v) => set(f.name, v)}
                  />
                ) : (
                  <Field label={f.label} required={f.required} error={errors[f.name]} hint={f.hint}>
                    {(a11y) =>
                      renderControl(
                        f,
                        String(values[f.name] ?? ''),
                        (v) => set(f.name, v),
                        { ...a11y, 'aria-required': f.required || undefined },
                        rooms,
                      )
                    }
                  </Field>
                )}
              </div>
            </Fragment>
          );
        })}
      </div>
      {children}
    </form>
  );
}

function renderControl(
  f: FieldDef,
  value: string,
  onChange: (v: string) => void,
  a11y: { id: string; 'aria-invalid'?: boolean; 'aria-describedby'?: string; 'aria-required'?: boolean },
  rooms?: Room[],
) {
  switch (f.type) {
    case 'textarea':
      return (
        <Textarea
          {...a11y}
          value={value}
          maxLength={f.maxLength ?? 5000}
          placeholder={f.placeholder}
          onChange={(e) => onChange(e.target.value)}
        />
      );
    case 'select':
      return (
        <Select {...a11y} value={value} onChange={(e) => onChange(e.target.value)}>
          {!f.required && <option value="">{f.placeholder ?? 'Choose…'}</option>}
          {f.options?.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </Select>
      );
    case 'category':
      return <CategorySelect {...a11y} kind={f.categoryKind!} value={value} onChange={onChange} placeholder={f.placeholder} />;
    case 'room':
      return (
        <Select {...a11y} value={value} onChange={(e) => onChange(e.target.value)}>
          <option value="">{rooms?.length ? 'No room' : 'No rooms added yet'}</option>
          {rooms?.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </Select>
      );
    case 'money':
      return (
        <div className="relative">
          <span className="text-muted pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2" aria-hidden>
            £
          </span>
          <Input
            {...a11y}
            type="number"
            inputMode="decimal"
            min={0}
            step="0.01"
            className="pl-8"
            value={value}
            placeholder={f.placeholder ?? '0.00'}
            onChange={(e) => onChange(e.target.value)}
          />
        </div>
      );
    case 'number':
      return (
        <Input
          {...a11y}
          type="number"
          inputMode="decimal"
          min={f.min}
          max={f.max}
          step={f.step ?? 'any'}
          value={value}
          placeholder={f.placeholder}
          onChange={(e) => onChange(e.target.value)}
        />
      );
    case 'date':
      return <Input {...a11y} type="date" value={value} onChange={(e) => onChange(e.target.value)} />;
    default:
      return (
        <Input
          {...a11y}
          type={f.type}
          inputMode={f.type === 'tel' ? 'tel' : f.type === 'email' ? 'email' : undefined}
          autoComplete={f.type === 'email' ? 'email' : f.type === 'tel' ? 'tel' : 'off'}
          value={value}
          maxLength={f.maxLength ?? 200}
          placeholder={f.placeholder}
          onChange={(e) => onChange(e.target.value)}
        />
      );
  }
}

interface FormModalProps extends Omit<EntityFormProps, 'id' | 'onBusyChange'> {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  submitLabel?: string;
  size?: 'md' | 'lg';
}

/** A modal containing an EntityForm with Save / Cancel buttons. Remounts the form on each open. */
export function FormModal({ open, onClose, title, description, submitLabel = 'Save', size = 'lg', ...form }: FormModalProps) {
  const [busy, setBusy] = useState(false);
  const formId = `form-${title.replace(/\W+/g, '-').toLowerCase()}`;
  return (
    <Modal
      open={open}
      onClose={() => !busy && onClose()}
      title={title}
      description={description}
      size={size}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button type="submit" form={formId} loading={busy}>
            {submitLabel}
          </Button>
        </>
      }
    >
      {open && <EntityForm id={formId} onBusyChange={setBusy} {...form} />}
    </Modal>
  );
}
