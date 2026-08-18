-- THIX ID Enterprise Dashboard Core (companies, RBAC, sessions, activity, security)
-- Date: 2026-05-13

create extension if not exists pgcrypto;

-- ==============================================================
-- Companies
-- ==============================================================
create table if not exists public.thix_enterprise_companies (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  legal_name text not null,
  trust_score int not null default 50,
  compliance_status text not null default 'OK',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ==============================================================
-- Enterprise roles
-- ==============================================================
do $$
begin
  if not exists (select 1 from pg_type where typname = 'thix_enterprise_role') then
    create type public.thix_enterprise_role as enum (
      'super_enterprise_admin',
      'ceo',
      'hr_director',
      'recruiter',
      'compliance_officer',
      'security_officer',
      'finance_manager',
      'department_manager',
      'moderator',
      'auditor'
    );
  end if;
end $$;

-- ==============================================================
-- Memberships (RBAC)
-- ==============================================================
create table if not exists public.thix_enterprise_memberships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.thix_enterprise_role not null,
  employee_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, user_id)
);

create index if not exists idx_thix_enterprise_memberships_company on public.thix_enterprise_memberships(company_id);
create index if not exists idx_thix_enterprise_memberships_user on public.thix_enterprise_memberships(user_id);

-- ==============================================================
-- Secure sessions (device/IP verification)
-- ==============================================================
create table if not exists public.thix_enterprise_sessions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_fingerprint text not null,
  ip inet,
  user_agent text,
  risk_score int not null default 0,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '8 hours')
);

create index if not exists idx_thix_enterprise_sessions_company on public.thix_enterprise_sessions(company_id);
create index if not exists idx_thix_enterprise_sessions_user on public.thix_enterprise_sessions(user_id);
create index if not exists idx_thix_enterprise_sessions_last_seen on public.thix_enterprise_sessions(company_id, last_seen_at);

-- ==============================================================
-- Activity feed
-- ==============================================================
create table if not exists public.thix_enterprise_activity (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  type text not null,
  title text not null,
  subtitle text not null default '',
  severity text not null default 'info',
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_thix_enterprise_activity_company on public.thix_enterprise_activity(company_id, created_at desc);

-- ==============================================================
-- Security alerts
-- ==============================================================
create table if not exists public.thix_enterprise_security_alerts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  type text not null,
  status text not null default 'open',
  title text not null,
  description text not null default '',
  risk_score int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_enterprise_security_alerts_company on public.thix_enterprise_security_alerts(company_id, created_at desc);

-- ==============================================================
-- Verification requests
-- ==============================================================
create table if not exists public.thix_enterprise_verification_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  target_thix_id text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_enterprise_verif_company on public.thix_enterprise_verification_requests(company_id, created_at desc);

-- ==============================================================
-- Attendance events (minimal scaffold)
-- ==============================================================
create table if not exists public.thix_enterprise_attendance_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  method text not null default 'qr',
  day_key text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_thix_enterprise_attendance_company_day on public.thix_enterprise_attendance_events(company_id, day_key);

-- ==============================================================
-- RLS
-- ==============================================================
alter table public.thix_enterprise_companies enable row level security;
alter table public.thix_enterprise_memberships enable row level security;
alter table public.thix_enterprise_sessions enable row level security;
alter table public.thix_enterprise_activity enable row level security;
alter table public.thix_enterprise_security_alerts enable row level security;
alter table public.thix_enterprise_verification_requests enable row level security;
alter table public.thix_enterprise_attendance_events enable row level security;

-- Helper: membership exists
create or replace function public.thix_is_enterprise_member(c_id uuid)
returns boolean
language sql
stable
as $$
  select exists(
    select 1 from public.thix_enterprise_memberships m
    where m.company_id = c_id and m.user_id = auth.uid()
  );
$$;

-- Companies: members can read their company.
drop policy if exists "enterprise_companies_select" on public.thix_enterprise_companies;
create policy "enterprise_companies_select"
on public.thix_enterprise_companies
for select
using (public.thix_is_enterprise_member(id));

-- Memberships: member can read memberships in same company.
drop policy if exists "enterprise_memberships_select" on public.thix_enterprise_memberships;
create policy "enterprise_memberships_select"
on public.thix_enterprise_memberships
for select
using (public.thix_is_enterprise_member(company_id));

-- Sessions: member can read own sessions; insert via edge function with service role.
drop policy if exists "enterprise_sessions_select" on public.thix_enterprise_sessions;
create policy "enterprise_sessions_select"
on public.thix_enterprise_sessions
for select
using (user_id = auth.uid());

-- Activity: members can read; insert limited to members.
drop policy if exists "enterprise_activity_select" on public.thix_enterprise_activity;
create policy "enterprise_activity_select"
on public.thix_enterprise_activity
for select
using (public.thix_is_enterprise_member(company_id));

drop policy if exists "enterprise_activity_insert" on public.thix_enterprise_activity;
create policy "enterprise_activity_insert"
on public.thix_enterprise_activity
for insert
with check (public.thix_is_enterprise_member(company_id));

-- Alerts: members can read.
drop policy if exists "enterprise_alerts_select" on public.thix_enterprise_security_alerts;
create policy "enterprise_alerts_select"
on public.thix_enterprise_security_alerts
for select
using (public.thix_is_enterprise_member(company_id));

-- Verification requests: members can read; members can insert.
drop policy if exists "enterprise_verifreq_select" on public.thix_enterprise_verification_requests;
create policy "enterprise_verifreq_select"
on public.thix_enterprise_verification_requests
for select
using (public.thix_is_enterprise_member(company_id));

drop policy if exists "enterprise_verifreq_insert" on public.thix_enterprise_verification_requests;
create policy "enterprise_verifreq_insert"
on public.thix_enterprise_verification_requests
for insert
with check (public.thix_is_enterprise_member(company_id) and requested_by = auth.uid());

-- Attendance: members can read; user can insert for self.
drop policy if exists "enterprise_attendance_select" on public.thix_enterprise_attendance_events;
create policy "enterprise_attendance_select"
on public.thix_enterprise_attendance_events
for select
using (public.thix_is_enterprise_member(company_id));

drop policy if exists "enterprise_attendance_insert" on public.thix_enterprise_attendance_events;
create policy "enterprise_attendance_insert"
on public.thix_enterprise_attendance_events
for insert
with check (public.thix_is_enterprise_member(company_id) and user_id = auth.uid());

-- ==============================================================
-- Updated_at triggers (minimal)
-- ==============================================================
create or replace function public.thix_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_thix_enterprise_companies_updated_at on public.thix_enterprise_companies;
create trigger trg_thix_enterprise_companies_updated_at before update on public.thix_enterprise_companies
for each row execute procedure public.thix_set_updated_at();

drop trigger if exists trg_thix_enterprise_memberships_updated_at on public.thix_enterprise_memberships;
create trigger trg_thix_enterprise_memberships_updated_at before update on public.thix_enterprise_memberships
for each row execute procedure public.thix_set_updated_at();

drop trigger if exists trg_thix_enterprise_alerts_updated_at on public.thix_enterprise_security_alerts;
create trigger trg_thix_enterprise_alerts_updated_at before update on public.thix_enterprise_security_alerts
for each row execute procedure public.thix_set_updated_at();

drop trigger if exists trg_thix_enterprise_verifreq_updated_at on public.thix_enterprise_verification_requests;
create trigger trg_thix_enterprise_verifreq_updated_at before update on public.thix_enterprise_verification_requests
for each row execute procedure public.thix_set_updated_at();
