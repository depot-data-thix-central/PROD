-- THIX ID / Supabase initial schema
--
-- Apply this using the Supabase panel (Migrations / SQL) inside Dreamflow.
-- This schema is designed from lib/models/app_user.dart.

-- Required for gen_random_uuid()
create extension if not exists "pgcrypto";

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  -- If you later switch to Supabase Auth, you can store auth.users.id here.
  auth_user_id uuid unique,

  thix_id text not null unique,
  thix_chat text not null default '',
  thix_score integer,

  email text not null,
  phone text,
  display_name text not null,
  account_type text not null check (account_type in ('personal', 'enterprise')),

  photo_url text,
  bio text,
  country_or_origin text,

  contact_phone text,
  marital_status text,
  gender text,
  occupation text,

  date_of_birth text,
  place_of_birth text,
  nationality text,
  address text,
  father_name text,
  mother_name text,
  emergency_contact_name text,
  emergency_contact_phone text,
  emergency_contact_relation text,

  registration_status text,

  education jsonb not null default '[]'::jsonb,
  experience jsonb not null default '[]'::jsonb,
  skills jsonb not null default '[]'::jsonb,
  enrollments jsonb not null default '[]'::jsonb,
  languages text[] not null default '{}',

  biometrics_enabled boolean not null default true,
  two_fa_enabled boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- NOTE: `create table if not exists` does NOT add missing columns when the
-- table already exists. These ALTERs make the schema file safely re-runnable.
alter table public.users add column if not exists auth_user_id uuid;

create index if not exists idx_users_thix_id on public.users (thix_id);
create index if not exists idx_users_email on public.users (email);
create index if not exists idx_users_auth_user_id on public.users (auth_user_id);
