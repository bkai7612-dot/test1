/**
 * In-browser stand-in for the Supabase client, used only by the prototype build
 * (vite.demo.config.ts aliases "@/lib/supabase" to this file). It implements the
 * subset of the query builder, RPCs, auth and storage that Homefolio uses, over an
 * in-memory store seeded with an example home. Data resets on reload.
 */
import { DEMO_USER, FK, createSeed, type Row, type Store } from './seed';

export const isSupabaseConfigured = true;
export const STORAGE_BUCKET = 'homefolio';
export const SITE_URL = 'https://app.homefolio.co.uk';

let store: Store = createSeed();
const files = new Map<string, string>(); // storage path → blob URL
for (const [path, url] of store.__files) files.set(path, url);

const uuid = () => crypto.randomUUID();
const nowIso = () => new Date().toISOString();
const todayStr = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
const table = (name: string): Row[] => (store[name] ??= []) as Row[];
const ok = <T>(data: T, count?: number) => ({ data, error: null, count: count ?? null });
const fail = (message: string, code?: string) => ({ data: null, error: { message, code }, count: null });

// ---------------------------------------------------------------------------
// Query builder
// ---------------------------------------------------------------------------

type Filter = (r: Row) => boolean;

function likeToRegex(pattern: string): RegExp {
  const esc = pattern
    .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    .replace(/%/g, '.*')
    .replace(/_/g, '.');
  return new RegExp(`^${esc}$`, 'is');
}

function parseSelect(cols: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let cur = '';
  for (const ch of cols) {
    if (ch === '(') depth++;
    if (ch === ')') depth--;
    if (ch === ',' && depth === 0) {
      parts.push(cur.trim());
      cur = '';
    } else cur += ch;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}

function project(base: string, row: Row, cols: string): Row {
  const out: Row = {};
  for (const part of parseSelect(cols)) {
    if (part === '*') Object.assign(out, row);
    else if (part.includes('(')) {
      const m = part.match(/^(?:(\w+):)?(\w+)\((.*)\)$/s)!;
      const alias = m[1] ?? m[2];
      const target = m[2];
      const inner = m[3];
      const parentFk = FK[target];
      if (parentFk && parentFk in row) {
        // Many-to-one: the base row points at the target.
        const parent = table(target).find((t) => t.id === row[parentFk]);
        out[alias] = parent ? project(target, parent, inner) : null;
      } else {
        // One-to-many: target rows point back at the base row.
        const children = table(target).filter((t) => t[FK[base]] === row.id);
        out[alias] = inner.trim() === 'count' ? [{ count: children.length }] : children.map((c) => project(target, c, inner));
      }
    } else out[part] = row[part] ?? null;
  }
  return out;
}

class Query implements PromiseLike<unknown> {
  private filters: Filter[] = [];
  private orders: { col: string; asc: boolean; nullsFirst: boolean }[] = [];
  private lim: number | null = null;
  private from = 0;
  private mode: 'select' | 'insert' | 'update' | 'delete' = 'select';
  private payload: Row | Row[] | null = null;
  private cols = '*';
  private returning = false;
  private singleMode: 'one' | 'maybe' | null = null;
  private wantCount = false;

  constructor(private name: string) {}

  select(cols = '*', opts?: { count?: string }) {
    if (this.mode === 'select') this.cols = cols;
    else {
      this.returning = true;
      this.cols = cols;
    }
    if (opts?.count) this.wantCount = true;
    return this;
  }
  insert(values: Row | Row[]) {
    this.mode = 'insert';
    this.payload = values;
    return this;
  }
  update(values: Row) {
    this.mode = 'update';
    this.payload = values;
    return this;
  }
  delete() {
    this.mode = 'delete';
    return this;
  }
  eq(col: string, v: unknown) {
    this.filters.push((r) => r[col] === v);
    return this;
  }
  is(col: string, v: null) {
    this.filters.push((r) => (r[col] ?? null) === v);
    return this;
  }
  not(col: string, _op: 'is', v: null) {
    this.filters.push((r) => (r[col] ?? null) !== v);
    return this;
  }
  or(expr: string) {
    const clauses = expr.split(',').map((c) => {
      const [col, op, ...rest] = c.split('.');
      const val = rest.join('.');
      return { col, op, re: likeToRegex(val), val };
    });
    this.filters.push((r) =>
      clauses.some((c) =>
        c.op === 'ilike' ? typeof r[c.col] === 'string' && c.re.test(r[c.col] as string) : r[c.col] === c.val,
      ),
    );
    return this;
  }
  order(col: string, opts?: { ascending?: boolean; nullsFirst?: boolean }) {
    const asc = opts?.ascending ?? true;
    this.orders.push({ col, asc, nullsFirst: opts?.nullsFirst ?? !asc });
    return this;
  }
  limit(n: number) {
    this.lim = n;
    return this;
  }
  range(from: number, to: number) {
    this.from = from;
    this.lim = to - from + 1;
    return this;
  }
  maybeSingle() {
    this.singleMode = 'maybe';
    return this;
  }
  single() {
    this.singleMode = 'one';
    return this;
  }

  private matches(): Row[] {
    return table(this.name).filter((r) => this.filters.every((f) => f(r)));
  }

  private sort(rows: Row[]): Row[] {
    return [...rows].sort((a, b) => {
      for (const o of this.orders) {
        const x = a[o.col] ?? null;
        const y = b[o.col] ?? null;
        if (x === y) continue;
        if (x === null) return o.nullsFirst ? -1 : 1;
        if (y === null) return o.nullsFirst ? 1 : -1;
        const cmp = typeof x === 'string' ? x.localeCompare(y as string) : (x as number) < (y as number) ? -1 : 1;
        return o.asc ? cmp : -cmp;
      }
      return 0;
    });
  }

  private run() {
    let rows: Row[];
    switch (this.mode) {
      case 'insert': {
        const list = Array.isArray(this.payload) ? this.payload : [this.payload!];
        rows = [];
        for (const values of list) {
          if (this.name === 'custom_categories' && table(this.name).some((c) => c.kind === values.kind && c.name === values.name))
            return fail('duplicate key value', '23505');
          if (this.name === 'council_tax' && table(this.name).some((c) => c.property_id === values.property_id))
            return fail('duplicate key value', '23505');
          const row: Row = {
            ...(DEFAULTS[this.name] ?? {}),
            id: uuid(),
            user_id: DEMO_USER.id,
            created_at: nowIso(),
            updated_at: nowIso(),
            ...values,
          };
          table(this.name).push(row);
          rows.push(row);
        }
        break;
      }
      case 'update':
        rows = this.matches();
        for (const r of rows) Object.assign(r, this.payload, { updated_at: nowIso() });
        break;
      case 'delete':
        rows = this.matches();
        for (const r of rows) cascadeDelete(this.name, r.id as string);
        break;
      default:
        rows = this.matches();
    }

    if (this.mode !== 'select' && !this.returning) return ok(null);
    const total = rows.length;
    rows = this.sort(rows);
    if (this.lim !== null) rows = rows.slice(this.from, this.from + this.lim);
    const data = rows.map((r) => project(this.name, r, this.cols));
    if (this.singleMode === 'one')
      return data.length === 1 ? ok(data[0]) : fail('JSON object requested, multiple (or no) rows returned');
    if (this.singleMode === 'maybe') return ok(data[0] ?? null);
    return ok(data, this.wantCount ? total : undefined);
  }

  then<A, B>(resolve?: ((v: unknown) => A | PromiseLike<A>) | null, reject?: ((e: unknown) => B | PromiseLike<B>) | null) {
    // A small delay keeps loading states honest without feeling slow.
    return new Promise((r) => setTimeout(r, 120)).then(() => this.run()).then(resolve, reject);
  }
}

const DEFAULTS: Record<string, Row> = {
  properties: {
    address_line1: null,
    address_line2: null,
    town: null,
    postcode: null,
    property_type: 'house',
    ownership_status: 'owner',
    bedrooms: null,
    bathrooms: null,
    year_built: null,
    move_in_date: null,
    notes: null,
    is_sample: false,
  },
  rooms: { room_type: null, notes: null },
  appliances: {
    room_id: null,
    category: null,
    brand: null,
    model: null,
    serial_number: null,
    purchase_date: null,
    purchase_price: null,
    retailer: null,
    condition: null,
    notes: null,
  },
  inventory_items: {
    room_id: null,
    category: null,
    brand: null,
    model: null,
    serial_number: null,
    purchase_date: null,
    purchase_price: null,
    current_value: null,
    retailer: null,
    notes: null,
  },
  warranties: { appliance_id: null, inventory_item_id: null, provider: null, start_date: null, expiry_date: null, notes: null },
  maintenance_tasks: {
    room_id: null,
    appliance_id: null,
    series_id: null,
    description: null,
    category: null,
    recurrence: 'none',
    recurrence_interval: null,
    recurrence_unit: null,
    completed_at: null,
    notes: null,
  },
  utilities: {
    label: null,
    provider: null,
    account_number: null,
    tariff: null,
    contract_start: null,
    contract_end: null,
    monthly_cost: null,
    contact_phone: null,
    contact_email: null,
    website: null,
    notes: null,
  },
  council_tax: { council: null, account_number: null, band: null, monthly_amount: null, payment_day: null, notes: null },
  insurance_policies: {
    provider: null,
    policy_number: null,
    start_date: null,
    renewal_date: null,
    premium: null,
    premium_frequency: 'yearly',
    contact_phone: null,
    emergency_phone: null,
    contact_email: null,
    notes: null,
  },
  meter_readings: { notes: null },
  household_members: {
    linked_user_id: null,
    relationship: null,
    email: null,
    phone: null,
    notes: null,
    is_emergency_contact: false,
  },
  emergency_contacts: { phone: null, alt_phone: null, email: null, notes: null },
  documents: {
    room_id: null,
    appliance_id: null,
    inventory_item_id: null,
    maintenance_task_id: null,
    insurance_policy_id: null,
    utility_id: null,
    council_tax_id: null,
    category: 'Other',
    file_path: null,
    file_name: null,
    mime_type: null,
    size_bytes: null,
    notes: null,
    extracted_text: null,
  },
  photos: {
    room_id: null,
    appliance_id: null,
    inventory_item_id: null,
    maintenance_task_id: null,
    meter_reading_id: null,
    caption: null,
  },
  custom_fields: { value: null, sort_order: 0 },
  ad_campaigns: {
    body: null,
    cta_label: 'Learn more',
    logo_url: null,
    weight: 1,
    active: true,
    price_per_month: null,
    notes: null,
  },
};

/** Mirrors the database's ON DELETE CASCADE / SET NULL rules. */
function cascadeDelete(name: string, id: string) {
  store[name] = table(name).filter((r) => r.id !== id);
  const fk = FK[name];
  if (name === 'properties') {
    for (const t of Object.keys(store))
      if (t !== '__files' && t !== 'properties') store[t] = table(t).filter((r) => r.property_id !== id);
    return;
  }
  if (!fk) return;
  const cascades = ['photos', ...(name === 'appliances' || name === 'inventory_items' ? ['warranties'] : [])];
  for (const t of Object.keys(store)) {
    if (t === '__files') continue;
    const rows = table(t);
    if (!rows.some((r) => fk in r)) continue;
    if (cascades.includes(t)) store[t] = rows.filter((r) => r[fk] !== id);
    else for (const r of rows) if (r[fk] === id) r[fk] = null;
  }
  if (name === 'rooms' || name === 'appliances' || name === 'inventory_items')
    store.custom_fields = table('custom_fields').filter((f) => f.entity_id !== id);
}

// ---------------------------------------------------------------------------
// RPCs (JavaScript versions of the SQL functions)
// ---------------------------------------------------------------------------

const addDays = (date: string, n: number) => {
  const d = new Date(`${date}T00:00:00`);
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
};
const addStep = (date: string, rec: string, interval: number | null, unit: string | null) => {
  const d = new Date(`${date}T00:00:00`);
  const map: Record<string, [string, number]> = {
    daily: ['day', 1],
    weekly: ['week', 1],
    monthly: ['month', 1],
    quarterly: ['month', 3],
    biannual: ['month', 6],
    yearly: ['year', 1],
  };
  const [u, n] = rec === 'custom' ? [unit!, interval!] : map[rec];
  if (u === 'day') d.setDate(d.getDate() + n);
  if (u === 'week') d.setDate(d.getDate() + 7 * n);
  if (u === 'month') d.setMonth(d.getMonth() + n);
  if (u === 'year') d.setFullYear(d.getFullYear() + n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
const cap = (s: string) => s.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
const fmt = (d: string) =>
  new Date(`${d}T00:00:00`).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

const RPC: Record<string, (args: Row) => unknown> = {
  property_summary: ({ p_property_id: p }) => {
    const t = todayStr();
    const tasks = table('maintenance_tasks').filter((m) => m.property_id === p && !m.completed_at);
    return {
      rooms: table('rooms').filter((r) => r.property_id === p).length,
      appliances: table('appliances').filter((r) => r.property_id === p).length,
      inventory: table('inventory_items').filter((r) => r.property_id === p).length,
      documents: table('documents').filter((r) => r.property_id === p).length,
      open_tasks: tasks.length,
      overdue_tasks: tasks.filter((m) => (m.due_date as string) < t).length,
      active_warranties: table('warranties').filter((w) => w.property_id === p && w.expiry_date && (w.expiry_date as string) >= t)
        .length,
    };
  },
  upcoming_reminders: ({ p_property_id: p, p_days }) => {
    const t = todayStr();
    const end = addDays(t, p_days as number);
    const within = (d: unknown) => typeof d === 'string' && d >= t && d <= end;
    const out: Row[] = [];
    for (const m of table('maintenance_tasks'))
      if (m.property_id === p && !m.completed_at && (m.due_date as string) <= end)
        out.push({ kind: 'maintenance', item_id: m.id, title: m.title, detail: m.category, due_date: m.due_date });
    for (const w of table('warranties'))
      if (w.property_id === p && within(w.expiry_date)) {
        const item = table(w.appliance_id ? 'appliances' : 'inventory_items').find(
          (i) => i.id === (w.appliance_id ?? w.inventory_item_id),
        );
        out.push({
          kind: 'warranty',
          item_id: item?.id,
          title: `${item?.name} warranty`,
          detail: w.appliance_id ? 'appliance' : 'inventory',
          due_date: w.expiry_date,
        });
      }
    for (const i of table('insurance_policies'))
      if (i.property_id === p && within(i.renewal_date))
        out.push({
          kind: 'insurance',
          item_id: i.id,
          title: `${i.provider ? `${i.provider} ` : ''}${cap(i.policy_type as string)} insurance`,
          detail: 'Renewal',
          due_date: i.renewal_date,
        });
    for (const u of table('utilities'))
      if (u.property_id === p && within(u.contract_end))
        out.push({
          kind: 'contract',
          item_id: u.id,
          title: `${u.provider ?? cap(u.utility_type as string)} contract`,
          detail: u.utility_type,
          due_date: u.contract_end,
        });
    return out.sort((a, b) => (a.due_date as string).localeCompare(b.due_date as string)).slice(0, 50);
  },
  search_home: ({ p_query, p_property_id: p }) => {
    const q = String(p_query).toLowerCase();
    const has = (...v: unknown[]) => v.some((x) => typeof x === 'string' && x.toLowerCase().includes(q));
    const inScope = (r: Row) => !p || r.property_id === p;
    const out: Row[] = [];
    const add = (kind: string, r: Row, title: unknown, subtitle: unknown[]) =>
      out.push({
        kind,
        item_id: r.id,
        title,
        subtitle: subtitle.filter(Boolean).join(' · ') || null,
        property_id: r.property_id,
      });
    for (const a of table('appliances'))
      if (inScope(a) && has(a.name, a.brand, a.model, a.category, a.serial_number, a.retailer, a.notes))
        add('appliance', a, a.name, [a.brand, a.model, a.category]);
    for (const i of table('inventory_items'))
      if (inScope(i) && has(i.name, i.brand, i.model, i.category, i.serial_number, i.notes))
        add('inventory', i, i.name, [i.brand, i.model, i.category]);
    for (const d of table('documents'))
      if (inScope(d) && has(d.name, d.category, d.file_name, d.notes, d.extracted_text))
        add('document', d, d.name, [d.category, d.file_name]);
    for (const m of table('maintenance_tasks'))
      if (inScope(m) && has(m.title, m.description, m.category, m.notes))
        add('maintenance', m, m.title, [m.category, m.completed_at ? 'Completed' : `Due ${fmt(m.due_date as string)}`]);
    for (const w of table('warranties')) {
      const item = table(w.appliance_id ? 'appliances' : 'inventory_items').find(
        (i) => i.id === (w.appliance_id ?? w.inventory_item_id),
      );
      if (inScope(w) && item && has(w.provider, item.name, item.brand, 'warranty'))
        out.push({
          kind: w.appliance_id ? 'warranty' : 'inventory_warranty',
          item_id: item.id,
          title: `${item.name} warranty`,
          subtitle: [w.provider, w.expiry_date && `Expires ${fmt(w.expiry_date as string)}`].filter(Boolean).join(' · '),
          property_id: w.property_id,
        });
    }
    for (const r of table('rooms')) if (inScope(r) && has(r.name, r.room_type, r.notes)) add('room', r, r.name, [r.room_type]);
    for (const u of table('utilities'))
      if (inScope(u) && has(u.provider, u.utility_type, u.label, u.account_number, u.notes))
        add('utility', u, u.label ?? cap(u.utility_type as string), [u.provider, u.tariff]);
    for (const i of table('insurance_policies'))
      if (inScope(i) && has(i.provider, i.policy_type, i.policy_number, i.notes, 'insurance'))
        add('insurance', i, i.provider ?? 'Insurance policy', [`${cap(i.policy_type as string)} insurance`, i.policy_number]);
    for (const e of table('emergency_contacts'))
      if (inScope(e) && has(e.name, e.contact_type, e.phone, e.notes)) add('contact', e, e.name, [e.contact_type, e.phone]);
    for (const h of table('household_members'))
      if (inScope(h) && has(h.name, h.relationship, h.email, h.phone)) add('household', h, h.name, [h.relationship, h.phone]);
    return out;
  },
  complete_maintenance_task: ({ p_task_id }) => {
    const t = table('maintenance_tasks').find((m) => m.id === p_task_id);
    if (!t) throw { message: 'Task not found' };
    if (t.completed_at) return null;
    t.completed_at = nowIso();
    if (t.recurrence === 'none') return null;
    let next = addStep(
      t.due_date as string,
      t.recurrence as string,
      t.recurrence_interval as number,
      t.recurrence_unit as string,
    );
    while (next <= todayStr())
      next = addStep(next, t.recurrence as string, t.recurrence_interval as number, t.recurrence_unit as string);
    const row: Row = {
      ...t,
      id: uuid(),
      series_id: t.series_id ?? t.id,
      due_date: next,
      completed_at: null,
      created_at: nowIso(),
      updated_at: nowIso(),
    };
    table('maintenance_tasks').push(row);
    return row.id;
  },
  reopen_maintenance_task: ({ p_task_id }) => {
    const t = table('maintenance_tasks').find((m) => m.id === p_task_id);
    if (!t) throw { message: 'Task not found' };
    if (t.recurrence !== 'none') {
      const series = t.series_id ?? t.id;
      store.maintenance_tasks = table('maintenance_tasks').filter(
        (m) => !(m.series_id === series && m.id !== t.id && !m.completed_at && (m.due_date as string) > (t.due_date as string)),
      );
    }
    t.completed_at = null;
    return null;
  },
  create_sample_home: () => {
    if (table('properties').some((p) => p.is_sample)) throw { message: 'You already have a sample home', code: 'P0001' };
    const extra = createSeed({ sample: true });
    for (const [k, rows] of Object.entries(extra)) if (k !== '__files') table(k).push(...(rows as Row[]));
    for (const [path, url] of extra.__files) files.set(path, url);
    return (extra.properties as Row[])[0].id;
  },
  storage_status: () => {
    const used = [...table('documents'), ...table('photos')].reduce((s, r) => s + Number(r.size_bytes ?? 0), 0);
    const plus = table('profiles')[0]?.plan === 'plus';
    return { used, limit: (plus ? 25 : 1) * 1024 ** 3, plus };
  },
  record_ad_event: ({ p_campaign, p_event }) => {
    const day = todayStr();
    let row = table('ad_stats').find((s) => s.campaign_id === p_campaign && s.day === day);
    if (!row) {
      row = { campaign_id: p_campaign, day, impressions: 0, clicks: 0 };
      table('ad_stats').push(row);
    }
    if (p_event === 'impression') row.impressions = Number(row.impressions) + 1;
    if (p_event === 'click') row.clicks = Number(row.clicks) + 1;
    return null;
  },
  ad_report: ({ p_from, p_to }) =>
    table('ad_campaigns').map((c) => {
      const stats = table('ad_stats').filter(
        (s) => s.campaign_id === c.id && (s.day as string) >= (p_from as string) && (s.day as string) <= (p_to as string),
      );
      return {
        campaign_id: c.id,
        advertiser: c.advertiser,
        placement: c.placement,
        views: stats.reduce((n, s) => n + Number(s.impressions), 0),
        clicks: stats.reduce((n, s) => n + Number(s.clicks), 0),
      };
    }),
  delete_my_account: () => {
    store = { __files: [] } as unknown as Store;
    return null;
  },
};

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

type AuthListener = (event: string, session: unknown) => void;
const listeners = new Set<AuthListener>();
const makeSession = (email: string) => ({
  access_token: 'demo',
  token_type: 'bearer',
  user: {
    id: DEMO_USER.id,
    email,
    user_metadata: { full_name: DEMO_USER.name },
    app_metadata: {},
    aud: 'authenticated',
    created_at: '2025-01-01T09:00:00Z',
  },
});
let session: ReturnType<typeof makeSession> | null = makeSession(DEMO_USER.email);
const emit = (event: string) => setTimeout(() => listeners.forEach((l) => l(event, session)), 0);
const delay = <T>(v: T) => new Promise<T>((r) => setTimeout(() => r(v), 250));

const auth = {
  getSession: () => Promise.resolve({ data: { session }, error: null }),
  onAuthStateChange(cb: AuthListener) {
    listeners.add(cb);
    return { data: { subscription: { unsubscribe: () => listeners.delete(cb) } } };
  },
  async signInWithPassword({ email, password }: { email: string; password: string }) {
    if (!password || password.length < 6)
      return delay({ data: { session: null, user: null }, error: { message: 'Invalid login credentials', status: 400 } });
    if (!table('profiles').length) store = createSeed();
    session = makeSession(email);
    emit('SIGNED_IN');
    return delay({ data: { session, user: session.user }, error: null });
  },
  async signUp({ email, options }: { email: string; password: string; options?: { data?: { full_name?: string } } }) {
    // A fresh account: empty store so the first-run experience is shown.
    store = {
      __files: [],
      profiles: [
        {
          id: DEMO_USER.id,
          full_name: options?.data?.full_name || null,
          plan: 'free',
          plan_expires_at: null,
          plan_source: null,
          is_admin: false,
          theme: 'system',
          reminder_window_days: 120,
          remind_maintenance: true,
          remind_warranties: true,
          remind_insurance: true,
          remind_contracts: true,
        },
      ],
    } as unknown as Store;
    session = makeSession(email);
    emit('SIGNED_IN');
    return delay({ data: { session, user: session.user }, error: null });
  },
  async signOut() {
    session = null;
    emit('SIGNED_OUT');
    return { error: null };
  },
  resetPasswordForEmail: () => delay({ data: {}, error: null }),
  async updateUser(values: { email?: string; password?: string }) {
    if (session && values.email) session.user.email = values.email;
    return delay({ data: { user: session?.user }, error: null });
  },
};

// ---------------------------------------------------------------------------
// Storage: files live in memory as blob URLs
// ---------------------------------------------------------------------------

const storage = {
  from: () => ({
    async upload(path: string, body: Blob) {
      files.set(path, URL.createObjectURL(body));
      return delay({ data: { path }, error: null });
    },
    async createSignedUrls(paths: string[]) {
      return { data: paths.map((p) => ({ path: p, signedUrl: files.get(p) ?? null })), error: null };
    },
    getPublicUrl(path: string) {
      return { data: { publicUrl: files.get(path) ?? '' } };
    },
    async createSignedUrl(path: string) {
      return { data: { signedUrl: files.get(path) ?? '' }, error: null };
    },
    async remove(paths: string[]) {
      paths.forEach((p) => files.delete(p));
      return { data: [], error: null };
    },
  }),
};

export const supabase = {
  from: (name: string) => new Query(name),
  rpc: async (name: string, args: Row = {}) => {
    await new Promise((r) => setTimeout(r, 150));
    try {
      return ok(RPC[name](args));
    } catch (e) {
      return { data: null, error: e };
    }
  },
  auth,
  storage,
};
