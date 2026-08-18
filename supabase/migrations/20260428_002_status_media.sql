-- Extend status updates to support media (photo/video/audio)

alter table if exists public.thix_status_updates
  alter column text drop not null;

alter table if exists public.thix_status_updates
  add column if not exists status_type text not null default 'text',
  add column if not exists media_url text,
  add column if not exists media_mime text,
  add column if not exists media_name text,
  add column if not exists media_size bigint;

create index if not exists thix_status_updates_uid_idx on public.thix_status_updates (uid);
create index if not exists thix_status_updates_type_idx on public.thix_status_updates (status_type);

-- Storage bucket for status media.
-- Note: this requires storage schema privileges; if it fails in your environment,
-- create the bucket manually in Supabase Dashboard: Storage -> New bucket -> thix-status
insert into storage.buckets (id, name, public)
values ('thix-status', 'thix-status', true)
on conflict (id) do nothing;
