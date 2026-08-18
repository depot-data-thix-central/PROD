-- PostgREST schema cache reload helper.
--
-- Why:
-- The Flutter app uses schema-safe writes that, on unknown columns (PGRST204),
-- tries to trigger a schema reload so new columns become visible immediately.
--
-- Supabase/PostgREST listens to NOTIFY channel `pgrst`.
-- This function is safe to call from authenticated clients.

begin;

create or replace function public.pgrst_schema_reload()
returns void
language plpgsql
as $$
begin
  notify pgrst, 'reload schema';
end;
$$;

grant execute on function public.pgrst_schema_reload() to authenticated;

commit;
