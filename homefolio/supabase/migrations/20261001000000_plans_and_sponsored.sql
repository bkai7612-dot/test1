-- Homefolio Plus plans, free-plan limits, sponsored cards and admin access.

-- ---------------------------------------------------------------------------
-- Plans
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column plan text not null default 'free' check (plan in ('free', 'plus')),
  add column plan_expires_at timestamptz,
  add column plan_source text,
  add column is_admin boolean not null default false;

-- Users may edit their preferences but never their plan or admin flag.
-- Plans are written only by the payment webhook (service role).
revoke update on public.profiles from authenticated;
grant update (full_name, theme, reminder_window_days, remind_maintenance, remind_warranties, remind_insurance, remind_contracts)
  on public.profiles to authenticated;

alter table public.photos add column size_bytes bigint;

create or replace function public.is_plus(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select plan = 'plus' and (plan_expires_at is null or plan_expires_at > now())
     from public.profiles where id = p_user),
    false
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select is_admin from public.profiles where id = (select auth.uid())), false);
$$;

-- Storage allowance in bytes: 1 GB free, 25 GB Plus.
create or replace function public.storage_limit(p_user uuid)
returns bigint
language sql
stable
set search_path = ''
as $$
  select case when public.is_plus(p_user) then 25::bigint * 1024 * 1024 * 1024 else 1024::bigint * 1024 * 1024 end;
$$;

create or replace function public.storage_used(p_user uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select sum(size_bytes) from public.documents where user_id = p_user), 0)
       + coalesce((select sum(size_bytes) from public.photos where user_id = p_user), 0);
$$;

revoke execute on function public.storage_used(uuid) from public, anon, authenticated;

-- What the app shows in Settings and checks before uploading.
create or replace function public.storage_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'used', public.storage_used((select auth.uid())),
    'limit', public.storage_limit((select auth.uid())),
    'plus', public.is_plus((select auth.uid()))
  );
$$;

revoke execute on function public.storage_status() from public, anon;
grant execute on function public.storage_status() to authenticated;

create or replace function public.enforce_property_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not new.is_sample
     and not public.is_plus(new.user_id)
     and exists (select 1 from public.properties where user_id = new.user_id and not is_sample) then
    raise exception 'Upgrade to Homefolio Plus to add more than one property.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger enforce_property_limit
  before insert on public.properties
  for each row execute function public.enforce_property_limit();

create or replace function public.enforce_storage_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.size_bytes, 0) > 0
     and public.storage_used(new.user_id) + new.size_bytes > public.storage_limit(new.user_id) then
    if public.is_plus(new.user_id) then
      raise exception 'You''ve used all 25 GB of your storage. Delete some files to make room.' using errcode = 'P0001';
    end if;
    raise exception 'You''ve used your 1 GB of free storage. Upgrade to Homefolio Plus for 25 GB.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger enforce_storage_limit
  before insert on public.documents
  for each row execute function public.enforce_storage_limit();

create trigger enforce_storage_limit
  before insert on public.photos
  for each row execute function public.enforce_storage_limit();

-- ---------------------------------------------------------------------------
-- Sponsored cards
-- ---------------------------------------------------------------------------

create table public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  advertiser text not null check (char_length(advertiser) between 1 and 80),
  placement text not null check (placement in ('dashboard', 'maintenance', 'appliances', 'utilities', 'insurance')),
  headline text not null check (char_length(headline) between 1 and 40),
  body text check (char_length(body) <= 90),
  cta_label text not null default 'Learn more' check (char_length(cta_label) between 1 and 18),
  url text not null check (url like 'https://%'),
  logo_url text,
  starts_on date not null,
  ends_on date not null,
  weight integer not null default 1 check (weight between 1 and 100),
  active boolean not null default true,
  price_per_month numeric(10, 2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ad_campaigns_dates check (ends_on >= starts_on)
);

create index ad_campaigns_live_idx on public.ad_campaigns (placement, starts_on, ends_on) where active;

create trigger set_updated_at before update on public.ad_campaigns
  for each row execute function public.set_updated_at();

alter table public.ad_campaigns enable row level security;

-- Everyone signed in can read live campaigns; admins can see and manage all.
create policy "Read live campaigns" on public.ad_campaigns
  for select to authenticated
  using ((active and current_date between starts_on and ends_on) or public.is_admin());

create policy "Admins manage campaigns" on public.ad_campaigns
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Daily totals only. No user or device is ever recorded.
create table public.ad_stats (
  campaign_id uuid not null references public.ad_campaigns (id) on delete cascade,
  day date not null default current_date,
  impressions integer not null default 0,
  clicks integer not null default 0,
  primary key (campaign_id, day)
);

alter table public.ad_stats enable row level security;

create policy "Admins read stats" on public.ad_stats
  for select to authenticated
  using (public.is_admin());

create or replace function public.record_ad_event(p_campaign uuid, p_event text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event not in ('impression', 'click') then
    raise exception 'Unknown event' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.ad_campaigns
    where id = p_campaign and active and current_date between starts_on and ends_on
  ) then
    return;
  end if;
  insert into public.ad_stats (campaign_id, impressions, clicks)
  values (p_campaign, (p_event = 'impression')::int, (p_event = 'click')::int)
  on conflict (campaign_id, day) do update set
    impressions = public.ad_stats.impressions + excluded.impressions,
    clicks = public.ad_stats.clicks + excluded.clicks;
end;
$$;

revoke execute on function public.record_ad_event(uuid, text) from public, anon;
grant execute on function public.record_ad_event(uuid, text) to authenticated;

-- Monthly report per campaign for the admin page.
create or replace function public.ad_report(p_from date, p_to date)
returns table (campaign_id uuid, advertiser text, placement text, views bigint, clicks bigint)
language sql
stable
set search_path = ''
as $$
  select c.id, c.advertiser, c.placement,
         coalesce(sum(s.impressions), 0)::bigint, coalesce(sum(s.clicks), 0)::bigint
  from public.ad_campaigns c
  left join public.ad_stats s on s.campaign_id = c.id and s.day between p_from and p_to
  where public.is_admin()
  group by c.id, c.advertiser, c.placement
  order by c.advertiser;
$$;

-- Public bucket for advertiser logos only (never user files).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ad-creatives', 'ad-creatives', true, 1048576, array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
on conflict (id) do nothing;

create policy "Admins upload ad creatives" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ad-creatives' and public.is_admin());

create policy "Admins update ad creatives" on storage.objects
  for update to authenticated
  using (bucket_id = 'ad-creatives' and public.is_admin())
  with check (bucket_id = 'ad-creatives' and public.is_admin());

create policy "Admins delete ad creatives" on storage.objects
  for delete to authenticated
  using (bucket_id = 'ad-creatives' and public.is_admin());
