-- PROPOSAL ONLY: not executed. Review the existing trips schema with the teammate
-- before choosing this independent table. Do not blindly run on an existing table.
begin;
create table public.saved_itineraries (
  id text not null check (id ~ '^[0-9a-f]{32}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  snapshot jsonb not null check (
    jsonb_typeof(snapshot) = 'object'
    and snapshot ? 'schemaVersion' and snapshot->>'schemaVersion' = '1'
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
grant select, insert, update, delete on public.saved_itineraries to authenticated;
revoke all on public.saved_itineraries from anon;
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
