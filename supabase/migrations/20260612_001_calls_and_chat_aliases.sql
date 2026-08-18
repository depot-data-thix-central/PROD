-- THIX Chat: calls + alias views for requested table names
-- Idempotent migration (safe to re-run).

begin;

-- 1) Calls history table
create table if not exists public.call_history (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid references public.thix_chat_chats(id) on delete set null,
  kind text not null default 'audio', -- audio | video
  status text not null default 'ongoing', -- ongoing | completed | missed | declined
  caller_id uuid not null,
  receiver_id uuid not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists call_history_receiver_status_idx on public.call_history (receiver_id, status, started_at desc);
create index if not exists call_history_caller_status_idx on public.call_history (caller_id, status, started_at desc);

alter table if exists public.call_history enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='call_history' and policyname='call_history_select_participants') then
    create policy call_history_select_participants on public.call_history
      for select to authenticated
      using (auth.uid() = caller_id or auth.uid() = receiver_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='call_history' and policyname='call_history_insert_caller') then
    create policy call_history_insert_caller on public.call_history
      for insert to authenticated
      with check (auth.uid() = caller_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='call_history' and policyname='call_history_update_participants') then
    create policy call_history_update_participants on public.call_history
      for update to authenticated
      using (auth.uid() = caller_id or auth.uid() = receiver_id)
      with check (auth.uid() = caller_id or auth.uid() = receiver_id);
  end if;
end $$;

-- 2) Alias views to match requested naming (chat_messages, user_status)
-- Note: views are read-only in the app; writes still go to thix_* tables.
create or replace view public.chat_messages as
select
  m.*, 
  p.display_name as sender_profile_display_name,
  p.avatar_url as sender_profile_avatar_url,
  p.national_id_number as sender_profile_national_id_number
from public.thix_chat_messages m
left join public.profiles p
  on p.id::text = m.sender_id;

create or replace view public.user_status as
select
  s.id,
  s.uid,
  s.display_name,
  s.thix_id,
  s.text,
  null::text as media_url,
  null::text as media_name,
  s.created_at,
  s.expires_at
from public.thix_status_updates s;

-- 3) Realtime publication (best effort)
do $$
begin
  begin
    alter publication supabase_realtime add table public.thix_chat_messages;
  exception when duplicate_object then null;
  when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.thix_chat_chats;
  exception when duplicate_object then null;
  when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.call_history;
  exception when duplicate_object then null;
  when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.thix_status_updates;
  exception when duplicate_object then null;
  when undefined_object then null;
  end;
end $$;

commit;
