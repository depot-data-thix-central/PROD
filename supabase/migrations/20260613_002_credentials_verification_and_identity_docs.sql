-- Add identity document media + verification fields, and allow admin verification.
-- Idempotent migration.

begin;

-- 1) Ensure RBAC table exists
create table if not exists public.thix_admin_memberships (
  user_id uuid primary key,
  role text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.thix_admin_memberships enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_admin_memberships' and policyname='admin_memberships_select_own'
  ) then
    create policy admin_memberships_select_own on public.thix_admin_memberships
      for select to authenticated
      using (auth.uid() = user_id);
  end if;
end $$;

-- 2) Extend profiles with identity document references
alter table if exists public.profiles
  add column if not exists id_document_front_doc_id text,
  add column if not exists id_document_back_doc_id text,
  add column if not exists id_document_selfie_doc_id text,
  add column if not exists id_verification_status text;

-- 3) Allow admins to update verification statuses
-- WARNING: Postgres RLS cannot restrict by column. We keep this policy narrow
-- by requiring an admin membership.

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_admin_update'
  ) then
    create policy profiles_admin_update on public.profiles
      for update to authenticated
      using (
        exists (
          select 1 from public.thix_admin_memberships m
          where m.user_id = auth.uid() and lower(m.role) in ('admin','super admin','super_admin','superadmin')
        )
      )
      with check (
        exists (
          select 1 from public.thix_admin_memberships m
          where m.user_id = auth.uid() and lower(m.role) in ('admin','super admin','super_admin','superadmin')
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='formations' and policyname='formations_admin_update'
  ) then
    create policy formations_admin_update on public.formations
      for update to authenticated
      using (
        exists (
          select 1 from public.thix_admin_memberships m
          where m.user_id = auth.uid() and lower(m.role) in ('admin','super admin','super_admin','superadmin')
        )
      )
      with check (
        exists (
          select 1 from public.thix_admin_memberships m
          where m.user_id = auth.uid() and lower(m.role) in ('admin','super admin','super_admin','superadmin')
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='experiences' and policyname='experiences_admin_update'
  ) then
    create policy experiences_admin_update on public.experiences
      for update to authenticated
      using (
        exists (
          select 1 from public.thix_admin_memberships m
          where m.user_id = auth.uid() and lower(m.role) in ('admin','super admin','super_admin','superadmin')
        )
      )
      with check (
        exists (
          select 1 from public.thix_admin_memberships m
          where m.user_id = auth.uid() and lower(m.role) in ('admin','super admin','super_admin','superadmin')
        )
      );
  end if;
end $$;

commit;
