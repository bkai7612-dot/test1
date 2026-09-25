-- Welcome tour: remember when each person finished (or skipped) it, so it shows
-- once per account rather than once per device.
alter table public.profiles add column if not exists tour_completed_at timestamptz;

grant update (tour_completed_at) on public.profiles to authenticated;
