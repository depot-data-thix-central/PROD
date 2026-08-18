-- THIX CHAT (Supabase) schema
-- Note: This migration is designed to be safe to re-run.

create table if not exists public.thix_chat_chats (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct',
  direct_key text unique,
  participants text[] not null,
  participant_name jsonb not null default '{}'::jsonb,
  participant_thix jsonb not null default '{}'::jsonb,
  last_message text not null default '',
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists thix_chat_chats_participants_gin on public.thix_chat_chats using gin (participants);
create index if not exists thix_chat_chats_last_message_at_idx on public.thix_chat_chats (last_message_at desc);

create table if not exists public.thix_chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.thix_chat_chats(id) on delete cascade,
  type text not null default 'text',
  sender_id text not null,
  sender_thix_id text,
  sender_name text,
  text text not null default '',
  -- Generic extras (nullable) to support stickers/attachments/meeting/call
  sticker text,
  file_name text,
  file_ext text,
  file_size bigint,
  download_url text,
  storage_path text,
  meeting_title text,
  meeting_scheduled_at timestamptz,
  meeting_duration_min int,
  meeting_location text,
  meeting_note text,
  call_kind text,
  call_status text,
  call_accepted_at timestamptz,
  call_declined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists thix_chat_messages_chat_id_created_at_idx on public.thix_chat_messages (chat_id, created_at desc);

create table if not exists public.thix_chat_reads (
  chat_id uuid not null references public.thix_chat_chats(id) on delete cascade,
  user_id text not null,
  read_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create index if not exists thix_chat_reads_user_id_idx on public.thix_chat_reads (user_id);

create table if not exists public.thix_status_updates (
  id uuid primary key default gen_random_uuid(),
  uid text not null,
  display_name text,
  thix_id text,
  text text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists thix_status_updates_expires_at_idx on public.thix_status_updates (expires_at desc);

-- If you plan to use RLS, enable it and add policies here.
-- For quick prototyping, leave RLS disabled.
