-- THIX ID Profiles (Supabase) schema
-- Goal: keep a private profile row and a public, sanitized projection in sync.
-- This migration is designed to be safe to re-run.

-- Private profile (owner-managed). In this project, user ids are strings (local/Firebase).
create table if not exists public.thix_profiles (
  user_id text primary key,
  thix_id text not null,
  display_name text not null default '',
  photo_url text,
  bio text,
  occupation text,
  country_or_origin text,
  thix_chat text,
  languages text[] not null default array[]::text[],

  education jsonb not null default '[]'::jsonb,
  experience jsonb not null default '[]'::jsonb,
  skills jsonb not null default '[]'::jsonb,
  certifications jsonb not null default '[]'::jsonb,
  documents jsonb not null default '[]'::jsonb,
  contacts jsonb not null default '[]'::jsonb,

  -- Visibility by section (ex: {"bio": true, "education": true, ...})
  visibility_settings jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists thix_profiles_thix_id_uq on public.thix_profiles (thix_id);
create index if not exists thix_profiles_updated_at_idx on public.thix_profiles (updated_at desc);

-- Public profile projection (read-only to app clients). Contains only public data.
create table if not exists public.thix_public_profiles (
  user_id text primary key,
  thix_id text not null,
  display_name text not null default '',
  photo_url text,
  bio text,
  occupation text,
  country_or_origin text,
  thix_chat text,
  languages text[] not null default array[]::text[],

  education jsonb not null default '[]'::jsonb,
  experience jsonb not null default '[]'::jsonb,
  skills jsonb not null default '[]'::jsonb,
  certifications jsonb not null default '[]'::jsonb,
  documents jsonb not null default '[]'::jsonb,
  contacts jsonb not null default '[]'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists thix_public_profiles_thix_id_uq on public.thix_public_profiles (thix_id);
create index if not exists thix_public_profiles_updated_at_idx on public.thix_public_profiles (updated_at desc);

-- Trigger function to keep public profile in sync.
create or replace function public.thix_sync_public_profile()
returns trigger
language plpgsql
as $$
declare
  v jsonb;
  show_bio boolean;
  show_education boolean;
  show_experience boolean;
  show_skills boolean;
  show_certifications boolean;
  show_documents boolean;
  show_contacts boolean;
begin
  v := coalesce(new.visibility_settings, '{}'::jsonb);

  show_bio := coalesce((v->>'bio')::boolean, true);
  show_education := coalesce((v->>'education')::boolean, true);
  show_experience := coalesce((v->>'experience')::boolean, true);
  show_skills := coalesce((v->>'skills')::boolean, true);
  show_certifications := coalesce((v->>'certifications')::boolean, true);
  show_documents := coalesce((v->>'documents')::boolean, true);
  show_contacts := coalesce((v->>'contacts')::boolean, false);

  insert into public.thix_public_profiles (
    user_id, thix_id, display_name, photo_url, bio, occupation, country_or_origin, thix_chat, languages,
    education, experience, skills, certifications, documents, contacts,
    created_at, updated_at
  ) values (
    new.user_id,
    new.thix_id,
    new.display_name,
    new.photo_url,
    case when show_bio then new.bio else null end,
    new.occupation,
    new.country_or_origin,
    new.thix_chat,
    new.languages,
    case when show_education then new.education else '[]'::jsonb end,
    case when show_experience then new.experience else '[]'::jsonb end,
    case when show_skills then new.skills else '[]'::jsonb end,
    case when show_certifications then new.certifications else '[]'::jsonb end,
    case when show_documents then new.documents else '[]'::jsonb end,
    case when show_contacts then new.contacts else '[]'::jsonb end,
    now(),
    now()
  )
  on conflict (user_id) do update set
    thix_id = excluded.thix_id,
    display_name = excluded.display_name,
    photo_url = excluded.photo_url,
    bio = excluded.bio,
    occupation = excluded.occupation,
    country_or_origin = excluded.country_or_origin,
    thix_chat = excluded.thix_chat,
    languages = excluded.languages,
    education = excluded.education,
    experience = excluded.experience,
    skills = excluded.skills,
    certifications = excluded.certifications,
    documents = excluded.documents,
    contacts = excluded.contacts,
    updated_at = now();

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists thix_profiles_sync_public on public.thix_profiles;
create trigger thix_profiles_sync_public
after insert or update on public.thix_profiles
for each row execute function public.thix_sync_public_profile();

-- Realtime: ensure the public table is part of the supabase_realtime publication.
do $$
begin
  begin
    alter publication supabase_realtime add table public.thix_public_profiles;
  exception when duplicate_object then
    -- already added
    null;
  when undefined_object then
    -- publication may not exist in some environments
    null;
  end;
end $$;
