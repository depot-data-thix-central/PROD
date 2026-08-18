-- THIX ID / Supabase initial RLS policies

alter table public.users enable row level security;

-- Allow authenticated users to read any public profile.
-- If you need stricter visibility later, replace this with a more restrictive policy.
drop policy if exists "users_select_authenticated" on public.users;
create policy "users_select_authenticated"
on public.users
for select
to authenticated
using (true);

-- Allow user creation/updates (required by generator instructions).
-- Note: For production, you should restrict this (e.g., to the user's auth_user_id).
drop policy if exists "users_insert_authenticated" on public.users;
create policy "users_insert_authenticated"
on public.users
for insert
to authenticated
with check (true);

drop policy if exists "users_update_authenticated" on public.users;
create policy "users_update_authenticated"
on public.users
for update
to authenticated
using (true)
with check (true);
