-- THIX ID / Supabase incremental schema update
--
-- Adds the missing `public.profiles` table expected by the Flutter app
-- (ProfileService, EmergencyService, SupabaseAuthManager).
--
-- Apply this migration using the Supabase panel inside Dreamflow.

create extension if not exists "pgcrypto";

-- 1) Ensure public.users can reference auth.users (for future joins / admin views)
alter table public.users add column if not exists auth_user_id uuid;

do $$
begin
  if not exists (
    select 1
    from information_schema.table_constraints tc
    where tc.table_schema = 'public'
      and tc.table_name = 'users'
      and tc.constraint_type = 'FOREIGN KEY'
      and tc.constraint_name = 'users_auth_user_id_fkey'
  ) then
    alter table public.users
      add constraint users_auth_user_id_fkey
      foreign key (auth_user_id)
      references auth.users (id)
      on delete set null;
  end if;
end $$;

-- 2) Create profiles table (keyed by auth.users.id)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,

  thix_id text not null default '' unique,
  thix_chat text not null default '',

  display_name text not null default '',
  full_name text,

  avatar_url text,
  photo_url text,

  bio text,
  competence text,

  profession text,
  occupation text,
  country_or_origin text,
  contact_phone text,
  marital_status text,
  gender text,
  date_of_birth text,
  place_of_birth text,
  nationality text,
  address text,
  father_name text,
  mother_name text,
  emergency_contact_name text,
  emergency_contact_phone text,
  emergency_contact_relation text,

  origin_province text,
  origin_territory text,
  origin_sector text,

  residence_country text,
  residence_province text,
  residence_territory text,
  residence_city text,
  residence_commune text,
  residence_quarter text,
  residence_avenue text,
  residence_number text,

  emergency_contacts jsonb not null default '[]'::jsonb,
  trusted_contacts jsonb not null default '[]'::jsonb,

  height text,
  weight text,
  blood_group text,
  has_physical_disability boolean,
  physical_disability_description text,

  national_id_number text,
  id_document_type text,
  id_document_issue_date text,
  id_document_expiry_date text,
  id_document_issue_place text,

  id_document_front_doc_id text,
  id_document_back_doc_id text,
  id_document_selfie_doc_id text,
  id_verification_status text,

  languages text[] not null default '{}',
  languages_detailed jsonb not null default '[]'::jsonb,
  trainings jsonb not null default '[]'::jsonb,

  education jsonb not null default '[]'::jsonb,
  experience jsonb not null default '[]'::jsonb,
  skills jsonb not null default '[]'::jsonb,
  certifications jsonb not null default '[]'::jsonb,
  documents jsonb not null default '[]'::jsonb,
  contacts jsonb not null default '[]'::jsonb,
  visibility jsonb not null default '{"bio": true, "education": true, "experience": true, "skills": true, "certifications": true, "documents": true, "contacts": false}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_thix_id on public.profiles (thix_id);

-- 3) Row-Level Security + default policies (authenticated users can CRUD)
alter table public.profiles enable row level security;

drop policy if exists "profiles_all_authenticated" on public.profiles;
create policy "profiles_all_authenticated"
on public.profiles
for all
to authenticated
using (true)
with check (true);

-- Keep existing behavior for public.users: ensure RLS enabled, and add permissive policies if missing
alter table public.users enable row level security;

drop policy if exists "users_select_authenticated" on public.users;
create policy "users_select_authenticated"
on public.users
for select
to authenticated
using (true);

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
