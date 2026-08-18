-- Ensure THIX IDs are unique (except placeholders).
-- This makes search/public profile/chat deterministic and prevents duplicates.

create unique index if not exists profiles_thix_id_unique
on public.profiles (thix_id)
where thix_id is not null
  and thix_id <> ''
  and upper(thix_id) <> 'THIX-PENDING'
  and upper(thix_id) <> 'THIX-000000';
