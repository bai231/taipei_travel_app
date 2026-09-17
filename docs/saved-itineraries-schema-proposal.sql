-- 2026-09-18: user reported success, owner policy verified, and RLS enabled=true.
-- Do NOT rerun in that database. Retained for reference/new environments only.
-- Run ONCE in the correct project's SQL Editor as postgres.
-- Creates only the independent saved_itineraries table and its support objects.
-- Does not change trips/trip_places. If objects already exist, stop and inspect.
begin;
create table public.saved_itineraries (
  id text not null check (id ~ '^[0-9a-f]{32}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  snapshot jsonb not null check (
    jsonb_typeof(snapshot) = 'object'
    and snapshot ? 'schemaVersion' and snapshot->'schemaVersion' = '2'::jsonb
    and snapshot ? 'days' and jsonb_typeof(snapshot->'days') = 'array'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.saved_itineraries enable row level security;
create policy saved_itineraries_owner on public.saved_itineraries
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
revoke all on public.saved_itineraries from public, anon, authenticated;
grant select, insert, update, delete on public.saved_itineraries to authenticated;
create function public.touch_saved_itinerary_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.created_at = old.created_at;
  new.updated_at = now();
  return new;
end;
$$;
create trigger saved_itineraries_updated_at before update on public.saved_itineraries
for each row execute function public.touch_saved_itinerary_updated_at();
commit;
