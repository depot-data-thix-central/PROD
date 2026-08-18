-- THIX CHAT v2 additions: groups + presence + typing
-- Idempotent migration (safe to re-run).

begin;

-- -----------------------------------------------------------------------------
-- 1) Groups support (minimal): reuse thix_chat_chats with extra columns
-- -----------------------------------------------------------------------------

alter table if exists public.thix_chat_chats
  add column if not exists title text,
  add column if not exists created_by uuid,
  add column if not exists avatar_url text;

-- Helpful indexes
create index if not exists thix_chat_chats_type_idx on public.thix_chat_chats (type);

-- -----------------------------------------------------------------------------
-- 2) Presence (online / last seen)
-- -----------------------------------------------------------------------------

create table if not exists public.thix_presence (
  user_id uuid primary key,
  is_online boolean not null default false,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.thix_presence enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='thix_presence' and policyname='presence_select_authenticated') then
    create policy presence_select_authenticated on public.thix_presence
      for select to authenticated
      using (true);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='thix_presence' and policyname='presence_upsert_self') then
    create policy presence_upsert_self on public.thix_presence
      for insert to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='thix_presence' and policyname='presence_update_self') then
    create policy presence_update_self on public.thix_presence
      for update to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 3) Typing indicator
-- -----------------------------------------------------------------------------

create table if not exists public.thix_chat_typing (
  chat_id uuid not null references public.thix_chat_chats(id) on delete cascade,
  user_id uuid not null,
  is_typing boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create index if not exists thix_chat_typing_chat_id_idx on public.thix_chat_typing (chat_id);

alter table if exists public.thix_chat_typing enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='thix_chat_typing' and policyname='typing_select_participants') then
    create policy typing_select_participants on public.thix_chat_typing
      for select to authenticated
      using (true);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='thix_chat_typing' and policyname='typing_upsert_self') then
    create policy typing_upsert_self on public.thix_chat_typing
      for insert to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='thix_chat_typing' and policyname='typing_update_self') then
    create policy typing_update_self on public.thix_chat_typing
      for update to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4) Realtime publication (best effort)
-- -----------------------------------------------------------------------------

do $$
begin
  begin
    alter publication supabase_realtime add table public.thix_presence;
  exception when duplicate_object then null;
  when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.thix_chat_typing;
  exception when duplicate_object then null;
  when undefined_object then null;
  end;
end $$;

commit;
