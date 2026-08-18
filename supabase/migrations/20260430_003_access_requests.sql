-- Access requests (viewer asks permission to see private parts of a profile)

create table if not exists public.thix_access_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id text not null,
  target_user_id text not null,
  status text not null default 'pending',
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thix_access_requests_unique_pair unique (requester_id, target_user_id),
  constraint thix_access_requests_status_check check (status in ('pending','approved','rejected'))
);

create index if not exists thix_access_requests_target_idx on public.thix_access_requests (target_user_id, created_at desc);
create index if not exists thix_access_requests_requester_idx on public.thix_access_requests (requester_id, created_at desc);

alter table public.thix_access_requests enable row level security;

-- Requester can create a request for a target
drop policy if exists "thix_access_requests_insert_own" on public.thix_access_requests;
create policy "thix_access_requests_insert_own" on public.thix_access_requests
for insert
to authenticated
with check (auth.uid()::text = requester_id);

-- Requester can read their requests
drop policy if exists "thix_access_requests_select_requester" on public.thix_access_requests;
create policy "thix_access_requests_select_requester" on public.thix_access_requests
for select
to authenticated
using (auth.uid()::text = requester_id);

-- Target can read incoming requests
drop policy if exists "thix_access_requests_select_target" on public.thix_access_requests;
create policy "thix_access_requests_select_target" on public.thix_access_requests
for select
to authenticated
using (auth.uid()::text = target_user_id);

-- Target can approve/reject incoming requests
drop policy if exists "thix_access_requests_update_target" on public.thix_access_requests;
create policy "thix_access_requests_update_target" on public.thix_access_requests
for update
to authenticated
using (auth.uid()::text = target_user_id)
with check (auth.uid()::text = target_user_id);

-- Keep updated_at fresh
create or replace function public.thix_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists thix_access_requests_touch on public.thix_access_requests;
create trigger thix_access_requests_touch
before update on public.thix_access_requests
for each row execute function public.thix_touch_updated_at();
