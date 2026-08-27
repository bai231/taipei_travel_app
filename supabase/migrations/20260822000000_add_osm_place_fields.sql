alter table public.test_osm_table
  add column if not exists name text,
  add column if not exists description text,
  add column if not exists latitude float8,
  add column if not exists longitude float8,
  add column if not exists address text,
  add column if not exists category text,
  add column if not exists cuisine text,
  add column if not exists opening_hours text,
  add column if not exists image text,
  add column if not exists website text,
  add column if not exists phone text,
  add column if not exists tags jsonb,
  add column if not exists rating numeric,
  add column if not exists price_level int4,
  add column if not exists estimatedCost int4,
  add column if not exists openMinutes int4,
  add column if not exists closeMinutes int4,
  add column if not exists source text,
  add column if not exists source_id text,
  add column if not exists osm_type text,
  add column if not exists stayTime int2,
  add column if not exists updated_at timestamptz;

create unique index if not exists test_osm_table_source_source_id_key
  on public.test_osm_table (source, source_id);
