-- Fix for existing databases where `public.users` was created earlier
-- without the `auth_user_id` column.
--
-- Root cause of failure:
--   create index if not exists idx_users_auth_user_id on public.users (auth_user_id);
--   ERROR: column "auth_user_id" does not exist

alter table public.users add column if not exists auth_user_id uuid;

create index if not exists idx_users_auth_user_id on public.users (auth_user_id);
