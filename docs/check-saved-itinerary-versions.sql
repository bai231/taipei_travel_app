-- Read-only. Run in the correct Supabase project's SQL Editor as postgres.
-- An app/anonymous user's count can be filtered by RLS and is not a global audit.
-- Step 1: run alone. NULL means this table does not exist in this project/schema.
select current_user as query_role,
       to_regclass('public.saved_itineraries') as snapshot_table;

-- Step 2: only run if Step 1 finds the table.
-- Returns counts only, not user IDs, titles, places or private itinerary data.
select count(*) as total_rows,
       count(*) filter (where snapshot->>'schemaVersion' = '1') as v1_rows,
       count(*) filter (where snapshot->>'schemaVersion' = '2') as v2_rows,
       count(*) filter (
         where snapshot->>'schemaVersion' is null
            or snapshot->>'schemaVersion' not in ('1', '2')
       ) as missing_or_other_version_rows
from public.saved_itineraries;

-- If there are missing/other versions, investigate rather than assuming v2.
-- If snapshots were stored in another schema/table, audit that source too.
-- No UPDATE/DELETE/ALTER is performed by this file.
