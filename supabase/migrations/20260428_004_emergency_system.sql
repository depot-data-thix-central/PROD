-- THIX ID Emergency System

-- Tables:
-- - thix_emergency_alerts: one row per alert
-- - thix_emergency_locations: time-series location points (realtime)
-- - thix_emergency_audit_logs: immutable audit log
-- - thix_safety_ads: optional sponsored safety content

create table if not exists public.thix_emergency_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  profile_thix_id text,
  type text not null,
  severity text not null default 'high',
  is_critical boolean not null default false,
  silent_mode boolean not null default false,
  status text not null default 'active',
  title text,
  description text,
  last_lat double precision,
  last_lng double precision,
  last_accuracy_m double precision,
  last_location_at timestamptz,
  audio_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_emergency_alerts_user_id on public.thix_emergency_alerts (user_id);
create index if not exists idx_thix_emergency_alerts_status on public.thix_emergency_alerts (status);
create index if not exists idx_thix_emergency_alerts_created_at on public.thix_emergency_alerts (created_at desc);

create table if not exists public.thix_emergency_locations (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.thix_emergency_alerts(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  accuracy_m double precision,
  speed_mps double precision,
  heading_deg double precision,
  captured_at timestamptz not null default now()
);

create index if not exists idx_thix_emergency_locations_alert_time on public.thix_emergency_locations (alert_id, captured_at desc);

create table if not exists public.thix_emergency_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id text,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_thix_emergency_audit_logs_created_at on public.thix_emergency_audit_logs (created_at desc);

create table if not exists public.thix_safety_ads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  cta_label text,
  cta_url text,
  sponsor_name text,
  priority int not null default 100,
  active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_safety_ads_active on public.thix_safety_ads (active, priority);

-- RLS (simple baseline): authenticated user can insert/select their own alerts.
alter table public.thix_emergency_alerts enable row level security;
alter table public.thix_emergency_locations enable row level security;
alter table public.thix_emergency_audit_logs enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_alerts' and policyname='alerts_select_own'
  ) then
    create policy alerts_select_own on public.thix_emergency_alerts
      for select to authenticated
      using (user_id = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_alerts' and policyname='alerts_insert_own'
  ) then
    create policy alerts_insert_own on public.thix_emergency_alerts
      for insert to authenticated
      with check (user_id = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_alerts' and policyname='alerts_update_own'
  ) then
    create policy alerts_update_own on public.thix_emergency_alerts
      for update to authenticated
      using (user_id = auth.uid()::text)
      with check (user_id = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_locations' and policyname='locations_select_via_alert'
  ) then
    create policy locations_select_via_alert on public.thix_emergency_locations
      for select to authenticated
      using (
        exists (
          select 1 from public.thix_emergency_alerts a
          where a.id = thix_emergency_locations.alert_id
            and a.user_id = auth.uid()::text
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_locations' and policyname='locations_insert_via_alert'
  ) then
    create policy locations_insert_via_alert on public.thix_emergency_locations
      for insert to authenticated
      with check (
        exists (
          select 1 from public.thix_emergency_alerts a
          where a.id = thix_emergency_locations.alert_id
            and a.user_id = auth.uid()::text
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_audit_logs' and policyname='audit_insert_authenticated'
  ) then
    create policy audit_insert_authenticated on public.thix_emergency_audit_logs
      for insert to authenticated
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_audit_logs' and policyname='audit_select_own'
  ) then
    create policy audit_select_own on public.thix_emergency_audit_logs
      for select to authenticated
      using (actor_user_id = auth.uid()::text);
  end if;
end $$;

-- Storage bucket for emergency audio evidence.
-- Note: this requires storage schema privileges; if it fails, create it manually:
-- Storage -> New bucket -> thix-emergency
insert into storage.buckets (id, name, public)
values ('thix-emergency', 'thix-emergency', false)
on conflict (id) do nothing;

-- Updated_at maintenance
create or replace function public.thix_set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_thix_emergency_alerts_updated_at on public.thix_emergency_alerts;
create trigger trg_thix_emergency_alerts_updated_at
before update on public.thix_emergency_alerts
for each row execute function public.thix_set_updated_at();

drop trigger if exists trg_thix_safety_ads_updated_at on public.thix_safety_ads;
create trigger trg_thix_safety_ads_updated_at
before update on public.thix_safety_ads
for each row execute function public.thix_set_updated_at();

-- Realtime publication
do $$
begin
  begin
    alter publication supabase_realtime add table public.thix_emergency_alerts;
  exception when others then
    null;
  end;
  begin
    alter publication supabase_realtime add table public.thix_emergency_locations;
  exception when others then
    null;
  end;
end $$;
