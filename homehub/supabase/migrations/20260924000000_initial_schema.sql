-- HomeHub initial schema
-- Every user-owned table carries user_id (defaulting to auth.uid()) and is
-- protected by Row Level Security so a user can only ever see their own rows.

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profiles (one per auth user)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  theme text not null default 'system' check (theme in ('system', 'light', 'dark')),
  reminder_window_days integer not null default 120 check (reminder_window_days between 7 and 365),
  remind_maintenance boolean not null default true,
  remind_warranties boolean not null default true,
  remind_insurance boolean not null default true,
  remind_contracts boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------------

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  address_line1 text,
  address_line2 text,
  town text,
  postcode text,
  property_type text not null default 'house',
  ownership_status text not null default 'owner',
  bedrooms smallint check (bedrooms between 0 and 100),
  bathrooms smallint check (bathrooms between 0 and 100),
  year_built smallint check (year_built between 1000 and 2200),
  move_in_date date,
  notes text,
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index properties_user_idx on public.properties (user_id);

-- Used by RLS policies on child tables to stop rows being attached to a
-- property the current user does not own.
create or replace function public.owns_property(p_property_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.properties
    where id = p_property_id and user_id = (select auth.uid())
  );
$$;

-- ---------------------------------------------------------------------------
-- Property-scoped tables
-- ---------------------------------------------------------------------------

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  room_type text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index rooms_property_idx on public.rooms (property_id);
create index rooms_user_idx on public.rooms (user_id);

create table public.appliances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  room_id uuid references public.rooms (id) on delete set null,
  name text not null check (char_length(name) between 1 and 200),
  category text,
  brand text,
  model text,
  serial_number text,
  purchase_date date,
  purchase_price numeric(12, 2) check (purchase_price >= 0),
  retailer text,
  condition text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index appliances_property_idx on public.appliances (property_id);
create index appliances_room_idx on public.appliances (room_id);
create index appliances_user_idx on public.appliances (user_id);
create index appliances_name_trgm on public.appliances using gin (name extensions.gin_trgm_ops);
create index appliances_brand_trgm on public.appliances using gin (brand extensions.gin_trgm_ops);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  room_id uuid references public.rooms (id) on delete set null,
  name text not null check (char_length(name) between 1 and 200),
  category text,
  brand text,
  model text,
  serial_number text,
  purchase_date date,
  purchase_price numeric(12, 2) check (purchase_price >= 0),
  current_value numeric(12, 2) check (current_value >= 0),
  retailer text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index inventory_property_idx on public.inventory_items (property_id);
create index inventory_room_idx on public.inventory_items (room_id);
create index inventory_user_idx on public.inventory_items (user_id);
create index inventory_name_trgm on public.inventory_items using gin (name extensions.gin_trgm_ops);
create index inventory_brand_trgm on public.inventory_items using gin (brand extensions.gin_trgm_ops);

-- A warranty belongs to exactly one appliance or one inventory item.
create table public.warranties (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  appliance_id uuid references public.appliances (id) on delete cascade,
  inventory_item_id uuid references public.inventory_items (id) on delete cascade,
  provider text,
  start_date date,
  expiry_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint warranties_one_parent check (num_nonnulls(appliance_id, inventory_item_id) = 1),
  constraint warranties_dates check (start_date is null or expiry_date is null or expiry_date >= start_date)
);
create index warranties_property_idx on public.warranties (property_id, expiry_date);
create index warranties_appliance_idx on public.warranties (appliance_id);
create index warranties_inventory_idx on public.warranties (inventory_item_id);
create index warranties_user_idx on public.warranties (user_id);

create table public.maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  room_id uuid references public.rooms (id) on delete set null,
  appliance_id uuid references public.appliances (id) on delete set null,
  -- All occurrences of a recurring task share the id of the first occurrence.
  series_id uuid,
  title text not null check (char_length(title) between 1 and 200),
  description text,
  category text,
  due_date date not null,
  recurrence text not null default 'none'
    check (recurrence in ('none', 'daily', 'weekly', 'monthly', 'quarterly', 'biannual', 'yearly', 'custom')),
  recurrence_interval smallint check (recurrence_interval between 1 and 999),
  recurrence_unit text check (recurrence_unit in ('day', 'week', 'month', 'year')),
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint maintenance_custom_recurrence check (
    recurrence <> 'custom' or (recurrence_interval is not null and recurrence_unit is not null)
  )
);
create index maintenance_property_due_idx on public.maintenance_tasks (property_id, due_date) where completed_at is null;
create index maintenance_property_completed_idx on public.maintenance_tasks (property_id, completed_at desc) where completed_at is not null;
create index maintenance_user_idx on public.maintenance_tasks (user_id);
create index maintenance_title_trgm on public.maintenance_tasks using gin (title extensions.gin_trgm_ops);

create table public.utilities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  utility_type text not null,
  label text,
  provider text,
  account_number text,
  tariff text,
  contract_start date,
  contract_end date,
  monthly_cost numeric(10, 2) check (monthly_cost >= 0),
  contact_phone text,
  contact_email text,
  website text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index utilities_property_idx on public.utilities (property_id);
create index utilities_user_idx on public.utilities (user_id);

create table public.council_tax (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null unique references public.properties (id) on delete cascade,
  council text,
  account_number text,
  band text,
  monthly_amount numeric(10, 2) check (monthly_amount >= 0),
  payment_day smallint check (payment_day between 1 and 31),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index council_tax_user_idx on public.council_tax (user_id);

create table public.insurance_policies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  policy_type text not null,
  provider text,
  policy_number text,
  start_date date,
  renewal_date date,
  premium numeric(10, 2) check (premium >= 0),
  premium_frequency text not null default 'yearly' check (premium_frequency in ('monthly', 'yearly')),
  contact_phone text,
  emergency_phone text,
  contact_email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index insurance_property_idx on public.insurance_policies (property_id, renewal_date);
create index insurance_user_idx on public.insurance_policies (user_id);

create table public.meter_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  meter_type text not null check (meter_type in ('electricity', 'gas', 'water')),
  reading numeric(14, 3) not null check (reading >= 0),
  reading_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index meter_readings_property_idx on public.meter_readings (property_id, meter_type, reading_date desc);
create index meter_readings_user_idx on public.meter_readings (user_id);

-- Household members are information only for now. linked_user_id is reserved
-- so a member can later be given their own login and shared access.
create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  linked_user_id uuid references auth.users (id) on delete set null,
  name text not null check (char_length(name) between 1 and 120),
  relationship text,
  email text,
  phone text,
  notes text,
  is_emergency_contact boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index household_property_idx on public.household_members (property_id);
create index household_user_idx on public.household_members (user_id);

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  contact_type text not null,
  name text not null check (char_length(name) between 1 and 120),
  phone text,
  alt_phone text,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index emergency_property_idx on public.emergency_contacts (property_id);
create index emergency_user_idx on public.emergency_contacts (user_id);

-- Files are stored in the private "homehub" bucket; these rows hold metadata.
-- A document can optionally be linked to one item. extracted_text is reserved
-- for future OCR / document recognition and is included in search.
create table public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  room_id uuid references public.rooms (id) on delete set null,
  appliance_id uuid references public.appliances (id) on delete set null,
  inventory_item_id uuid references public.inventory_items (id) on delete set null,
  maintenance_task_id uuid references public.maintenance_tasks (id) on delete set null,
  insurance_policy_id uuid references public.insurance_policies (id) on delete set null,
  utility_id uuid references public.utilities (id) on delete set null,
  council_tax_id uuid references public.council_tax (id) on delete set null,
  name text not null check (char_length(name) between 1 and 200),
  category text not null default 'Other',
  file_path text,
  file_name text,
  mime_type text,
  size_bytes bigint,
  notes text,
  extracted_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index documents_property_idx on public.documents (property_id, created_at desc);
create index documents_user_idx on public.documents (user_id);
create index documents_appliance_idx on public.documents (appliance_id);
create index documents_inventory_idx on public.documents (inventory_item_id);
create index documents_room_idx on public.documents (room_id);
create index documents_task_idx on public.documents (maintenance_task_id);
create index documents_insurance_idx on public.documents (insurance_policy_id);
create index documents_utility_idx on public.documents (utility_id);
create index documents_council_tax_idx on public.documents (council_tax_id);
create index documents_name_trgm on public.documents using gin (name extensions.gin_trgm_ops);

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  room_id uuid references public.rooms (id) on delete cascade,
  appliance_id uuid references public.appliances (id) on delete cascade,
  inventory_item_id uuid references public.inventory_items (id) on delete cascade,
  maintenance_task_id uuid references public.maintenance_tasks (id) on delete cascade,
  meter_reading_id uuid references public.meter_readings (id) on delete cascade,
  file_path text not null,
  caption text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index photos_property_idx on public.photos (property_id, created_at desc);
create index photos_user_idx on public.photos (user_id);
create index photos_room_idx on public.photos (room_id);
create index photos_appliance_idx on public.photos (appliance_id);
create index photos_inventory_idx on public.photos (inventory_item_id);
create index photos_task_idx on public.photos (maintenance_task_id);
create index photos_meter_idx on public.photos (meter_reading_id);

-- Extra user-defined fields ("Label: value") attached to any record.
create table public.custom_fields (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  entity_type text not null check (entity_type in ('property', 'room', 'appliance', 'inventory')),
  entity_id uuid not null,
  label text not null check (char_length(label) between 1 and 80),
  value text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index custom_fields_entity_idx on public.custom_fields (entity_type, entity_id);
create index custom_fields_user_idx on public.custom_fields (user_id);

-- ---------------------------------------------------------------------------
-- User-level tables
-- ---------------------------------------------------------------------------

-- User-created categories that extend the built-in lists in the app.
create table public.custom_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('room', 'appliance', 'inventory', 'document', 'utility', 'maintenance', 'contact')),
  name text not null check (char_length(name) between 1 and 60),
  created_at timestamptz not null default now(),
  unique (user_id, kind, name)
);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'properties', 'rooms', 'appliances', 'inventory_items', 'warranties',
    'maintenance_tasks', 'utilities', 'council_tax', 'insurance_policies', 'meter_readings',
    'household_members', 'emergency_contacts', 'documents', 'photos', 'custom_fields'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      t
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
create policy "Users can view own profile" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "Users can update own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

alter table public.properties enable row level security;
create policy "Users manage own properties" on public.properties
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter table public.custom_categories enable row level security;
create policy "Users manage own categories" on public.custom_categories
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

do $$
declare
  t text;
begin
  foreach t in array array[
    'rooms', 'appliances', 'inventory_items', 'warranties', 'maintenance_tasks', 'utilities',
    'council_tax', 'insurance_policies', 'meter_readings', 'household_members',
    'emergency_contacts', 'documents', 'photos', 'custom_fields'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "Users read own rows" on public.%I for select to authenticated using (user_id = (select auth.uid()))',
      t
    );
    execute format(
      'create policy "Users insert own rows" on public.%I for insert to authenticated with check (user_id = (select auth.uid()) and public.owns_property(property_id))',
      t
    );
    execute format(
      'create policy "Users update own rows" on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and public.owns_property(property_id))',
      t
    );
    execute format(
      'create policy "Users delete own rows" on public.%I for delete to authenticated using (user_id = (select auth.uid()))',
      t
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage: private bucket, files live under "<user_id>/<property_id>/..."
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'homehub',
  'homehub',
  false,
  20971520,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif',
    'application/pdf', 'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do nothing;

create policy "Users read own files" on storage.objects
  for select to authenticated
  using (bucket_id = 'homehub' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Users upload own files" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'homehub' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Users update own files" on storage.objects
  for update to authenticated
  using (bucket_id = 'homehub' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'homehub' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Users delete own files" on storage.objects
  for delete to authenticated
  using (bucket_id = 'homehub' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------------------
-- RPC: maintenance completion with automatic next occurrence
-- ---------------------------------------------------------------------------

create or replace function public.recurrence_step(p_recurrence text, p_interval integer, p_unit text)
returns interval
language sql
immutable
set search_path = ''
as $$
  select case p_recurrence
    when 'daily' then interval '1 day'
    when 'weekly' then interval '1 week'
    when 'monthly' then interval '1 month'
    when 'quarterly' then interval '3 months'
    when 'biannual' then interval '6 months'
    when 'yearly' then interval '1 year'
    when 'custom' then case p_unit
      when 'day' then make_interval(days => p_interval)
      when 'week' then make_interval(weeks => p_interval)
      when 'month' then make_interval(months => p_interval)
      when 'year' then make_interval(years => p_interval)
    end
  end;
$$;

-- Marks a task complete and, for recurring tasks, creates the next occurrence.
-- Returns the id of the new occurrence (or null if the task does not repeat).
create or replace function public.complete_maintenance_task(p_task_id uuid)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  t public.maintenance_tasks;
  step interval;
  next_due date;
  new_id uuid;
begin
  select * into t from public.maintenance_tasks where id = p_task_id for update;
  if not found then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;
  if t.completed_at is not null then
    return null;
  end if;

  update public.maintenance_tasks set completed_at = now() where id = t.id;

  step := public.recurrence_step(t.recurrence, t.recurrence_interval, t.recurrence_unit);
  if step is null then
    return null;
  end if;

  -- Next occurrence follows the original schedule, skipping dates already past.
  next_due := (t.due_date + step)::date;
  while next_due <= current_date loop
    next_due := (next_due + step)::date;
  end loop;

  insert into public.maintenance_tasks (
    user_id, property_id, room_id, appliance_id, series_id, title, description, category,
    due_date, recurrence, recurrence_interval, recurrence_unit, notes
  ) values (
    t.user_id, t.property_id, t.room_id, t.appliance_id, coalesce(t.series_id, t.id), t.title,
    t.description, t.category, next_due, t.recurrence, t.recurrence_interval, t.recurrence_unit, t.notes
  )
  returning id into new_id;

  return new_id;
end;
$$;

-- Reverses a completion. Any not-yet-completed follow-up occurrence created
-- by completing this task is removed so the schedule does not double up.
create or replace function public.reopen_maintenance_task(p_task_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  t public.maintenance_tasks;
begin
  select * into t from public.maintenance_tasks where id = p_task_id for update;
  if not found then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if t.recurrence <> 'none' then
    delete from public.maintenance_tasks
    where series_id = coalesce(t.series_id, t.id)
      and id <> t.id
      and completed_at is null
      and due_date > t.due_date;
  end if;

  update public.maintenance_tasks set completed_at = null where id = t.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: dashboard
-- ---------------------------------------------------------------------------

create or replace function public.property_summary(p_property_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'rooms', (select count(*) from public.rooms where property_id = p_property_id),
    'appliances', (select count(*) from public.appliances where property_id = p_property_id),
    'inventory', (select count(*) from public.inventory_items where property_id = p_property_id),
    'documents', (select count(*) from public.documents where property_id = p_property_id),
    'open_tasks', (select count(*) from public.maintenance_tasks where property_id = p_property_id and completed_at is null),
    'overdue_tasks', (select count(*) from public.maintenance_tasks where property_id = p_property_id and completed_at is null and due_date < current_date),
    'active_warranties', (select count(*) from public.warranties where property_id = p_property_id and expiry_date >= current_date)
  );
$$;

-- Everything with a date coming up (or overdue maintenance) for one property.
create or replace function public.upcoming_reminders(p_property_id uuid, p_days integer default 120)
returns table (kind text, item_id uuid, title text, detail text, due_date date)
language sql
stable
set search_path = ''
as $$
  select 'maintenance', m.id, m.title, m.category, m.due_date
  from public.maintenance_tasks m
  where m.property_id = p_property_id
    and m.completed_at is null
    and m.due_date <= current_date + p_days

  union all
  select 'warranty', coalesce(w.appliance_id, w.inventory_item_id),
         coalesce(a.name, i.name) || ' warranty',
         case when w.appliance_id is not null then 'appliance' else 'inventory' end,
         w.expiry_date
  from public.warranties w
  left join public.appliances a on a.id = w.appliance_id
  left join public.inventory_items i on i.id = w.inventory_item_id
  where w.property_id = p_property_id
    and w.expiry_date between current_date and current_date + p_days

  union all
  select 'insurance', p.id,
         coalesce(p.provider || ' ', '') || initcap(replace(p.policy_type, '_', ' ')) || ' insurance',
         'Renewal', p.renewal_date
  from public.insurance_policies p
  where p.property_id = p_property_id
    and p.renewal_date between current_date and current_date + p_days

  union all
  select 'contract', u.id,
         coalesce(u.provider, coalesce(u.label, initcap(u.utility_type))) || ' contract',
         coalesce(u.label, initcap(u.utility_type)), u.contract_end
  from public.utilities u
  where u.property_id = p_property_id
    and u.contract_end between current_date and current_date + p_days

  order by 5 asc
  limit 50;
$$;

-- ---------------------------------------------------------------------------
-- RPC: global search (RLS still applies: functions are security invoker)
-- ---------------------------------------------------------------------------

create or replace function public.search_home(p_query text, p_property_id uuid default null)
returns table (kind text, item_id uuid, title text, subtitle text, property_id uuid)
language sql
stable
set search_path = ''
as $$
  with q as (
    select '%' || replace(replace(replace(trim(p_query), '\', '\\'), '%', '\%'), '_', '\_') || '%' as pat
  )
  (
    select 'appliance', a.id, a.name, concat_ws(' · ', a.brand, a.model, a.category), a.property_id
    from public.appliances a, q
    where (p_property_id is null or a.property_id = p_property_id)
      and (a.name ilike q.pat or a.brand ilike q.pat or a.model ilike q.pat or a.category ilike q.pat
           or a.serial_number ilike q.pat or a.retailer ilike q.pat or a.notes ilike q.pat)
    limit 20
  )
  union all
  (
    select 'inventory', i.id, i.name, concat_ws(' · ', i.brand, i.model, i.category), i.property_id
    from public.inventory_items i, q
    where (p_property_id is null or i.property_id = p_property_id)
      and (i.name ilike q.pat or i.brand ilike q.pat or i.model ilike q.pat or i.category ilike q.pat
           or i.serial_number ilike q.pat or i.notes ilike q.pat)
    limit 20
  )
  union all
  (
    select 'document', d.id, d.name, concat_ws(' · ', d.category, d.file_name), d.property_id
    from public.documents d, q
    where (p_property_id is null or d.property_id = p_property_id)
      and (d.name ilike q.pat or d.category ilike q.pat or d.file_name ilike q.pat
           or d.notes ilike q.pat or d.extracted_text ilike q.pat)
    limit 20
  )
  union all
  (
    select 'maintenance', m.id, m.title,
           concat_ws(' · ', m.category, case when m.completed_at is null then 'Due ' || to_char(m.due_date, 'DD Mon YYYY') else 'Completed' end),
           m.property_id
    from public.maintenance_tasks m, q
    where (p_property_id is null or m.property_id = p_property_id)
      and (m.title ilike q.pat or m.description ilike q.pat or m.category ilike q.pat or m.notes ilike q.pat)
    order by m.completed_at is not null, m.due_date
    limit 20
  )
  union all
  (
    select case when w.appliance_id is not null then 'warranty' else 'inventory_warranty' end,
           coalesce(w.appliance_id, w.inventory_item_id), coalesce(a.name, i.name) || ' warranty',
           concat_ws(' · ', w.provider, 'Expires ' || to_char(w.expiry_date, 'DD Mon YYYY')), w.property_id
    from public.warranties w
    left join public.appliances a on a.id = w.appliance_id
    left join public.inventory_items i on i.id = w.inventory_item_id
    cross join q
    where (p_property_id is null or w.property_id = p_property_id)
      and (w.provider ilike q.pat or a.name ilike q.pat or a.brand ilike q.pat or i.name ilike q.pat
           or i.brand ilike q.pat or 'warranty' ilike q.pat)
    limit 20
  )
  union all
  (
    select 'room', r.id, r.name, r.room_type, r.property_id
    from public.rooms r, q
    where (p_property_id is null or r.property_id = p_property_id)
      and (r.name ilike q.pat or r.room_type ilike q.pat or r.notes ilike q.pat)
    limit 10
  )
  union all
  (
    select 'utility', u.id, coalesce(u.label, initcap(u.utility_type)), concat_ws(' · ', u.provider, u.tariff), u.property_id
    from public.utilities u, q
    where (p_property_id is null or u.property_id = p_property_id)
      and (u.provider ilike q.pat or u.utility_type ilike q.pat or u.label ilike q.pat
           or u.account_number ilike q.pat or u.notes ilike q.pat)
    limit 10
  )
  union all
  (
    select 'insurance', p.id, coalesce(p.provider, 'Insurance policy'),
           concat_ws(' · ', initcap(replace(p.policy_type, '_', ' ')) || ' insurance', p.policy_number), p.property_id
    from public.insurance_policies p, q
    where (p_property_id is null or p.property_id = p_property_id)
      and (p.provider ilike q.pat or p.policy_type ilike q.pat or p.policy_number ilike q.pat
           or p.notes ilike q.pat or 'insurance' ilike q.pat)
    limit 10
  )
  union all
  (
    select 'contact', e.id, e.name, concat_ws(' · ', e.contact_type, e.phone), e.property_id
    from public.emergency_contacts e, q
    where (p_property_id is null or e.property_id = p_property_id)
      and (e.name ilike q.pat or e.contact_type ilike q.pat or e.phone ilike q.pat or e.notes ilike q.pat)
    limit 10
  )
  union all
  (
    select 'household', h.id, h.name, concat_ws(' · ', h.relationship, h.phone), h.property_id
    from public.household_members h, q
    where (p_property_id is null or h.property_id = p_property_id)
      and (h.name ilike q.pat or h.relationship ilike q.pat or h.email ilike q.pat or h.phone ilike q.pat)
    limit 10
  );
$$;

-- ---------------------------------------------------------------------------
-- RPC: account deletion. The client removes stored files first; deleting the
-- auth user then cascades to every row the user owns.
-- ---------------------------------------------------------------------------

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  delete from auth.users where id = uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
