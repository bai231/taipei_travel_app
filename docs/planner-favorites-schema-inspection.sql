-- Read-only schema inspection. Run each SELECT separately if the editor
-- displays only the last result. No keys, tokens or user records are queried.
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('favorites', 'folders', 'folder_places', 'places')
order by table_name, ordinal_position;

select c.relname as table_name, con.conname as constraint_name,
       pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('favorites', 'folders', 'folder_places', 'places');

select c.relname as table_name, c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('favorites', 'folders', 'folder_places', 'places');

select tablename, policyname, roles, cmd, qual, with_check
from pg_policies where schemaname = 'public'
  and tablename in ('favorites', 'folders', 'folder_places', 'places');
