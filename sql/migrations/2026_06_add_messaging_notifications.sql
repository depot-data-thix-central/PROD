-- sql/migrations/2026_06_add_messaging_notifications.sql

-- Requires pgcrypto or gen_random_uuid()

create extension if not exists "pgcrypto";

-- Conversations
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  title text,
  created_at timestamptz default now()
);

create table if not exists conversation_participants (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade,
  profile_id uuid,
  joined_at timestamptz default now(),
  unique (conversation_id, profile_id)
);

-- Messages
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade,
  sender_profile_id uuid,
  content text,
  media jsonb,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_messages_conversation_created_at on messages(conversation_id, created_at desc);

-- Notifications
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  actor_id uuid,
  type text,
  data jsonb,
  read boolean default false,
  created_at timestamptz default now()
);
create index if not exists idx_notifications_user_created_at on notifications(user_id, created_at desc);

-- Device tokens (for push)
create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid,
  provider text,
  token text,
  created_at timestamptz default now()
);

-- Sample RPC to mark notification read
create or replace function mark_notification_read(nid uuid) returns void language plpgsql as $$
begin
  update notifications set read = true where id = nid;
end;
$$;

-- RPC to create a notification (used by triggers or Edge functions)
create or replace function create_notification(p_user_id uuid, p_actor_id uuid, p_type text, p_data jsonb) returns void language plpgsql as $$
begin
  insert into notifications (user_id, actor_id, type, data) values (p_user_id, p_actor_id, p_type, p_data);
end;
$$;

-- RPC helper to create conversation and participant
create or replace function create_conversation(p_title text, p_participants uuid[]) returns uuid language plpgsql as $$
declare
  cid uuid;
  pid uuid;
begin
  insert into conversations (title) values (p_title) returning id into cid;
  foreach pid in array p_participants loop
    insert into conversation_participants (conversation_id, profile_id) values (cid, pid) on conflict do nothing;
  end loop;
  return cid;
end;
$$;
