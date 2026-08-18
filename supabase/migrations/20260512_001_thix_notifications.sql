-- THIX Notifications (in-app)
-- This table is used by Flutter to deliver in-app notifications (including access requests).

create table if not exists public.thix_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null default 'generic',
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists thix_notifications_user_id_created_at_idx
  on public.thix_notifications(user_id, created_at desc);

alter table public.thix_notifications enable row level security;

-- Owner can read their notifications
drop policy if exists "thix_notifications_select_own" on public.thix_notifications;
create policy "thix_notifications_select_own" on public.thix_notifications
  for select
  using (auth.uid() = user_id);

-- Any authenticated user can insert notifications (e.g., access request to another user)
drop policy if exists "thix_notifications_insert_authenticated" on public.thix_notifications;
create policy "thix_notifications_insert_authenticated" on public.thix_notifications
  for insert
  with check (auth.uid() is not null);

-- Owner can mark as read
drop policy if exists "thix_notifications_update_own" on public.thix_notifications;
create policy "thix_notifications_update_own" on public.thix_notifications
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
