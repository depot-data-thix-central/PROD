-- Ensures signup/profile writes work with Supabase Auth + RLS.
-- Fixes: "new row violates row-level security policy for table profiles" (42501)

begin;

-- Some projects already have RLS enabled; keep this idempotent.
alter table if exists public.profiles enable row level security;

-- Read: allow public read (app uses public profile pages/suggestions).
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_select_public'
  ) then
    create policy profiles_select_public
      on public.profiles
      for select
      using (true);
  end if;
end $$;

-- Insert: allow authenticated user to create their own row.
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_insert_own'
  ) then
    create policy profiles_insert_own
      on public.profiles
      for insert
      to authenticated
      with check (auth.uid() = id);
  end if;
end $$;

-- Update: allow authenticated user to update their own row.
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_update_own'
  ) then
    create policy profiles_update_own
      on public.profiles
      for update
      to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end $$;

commit;
