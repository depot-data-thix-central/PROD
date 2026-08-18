-- Fix missing schema-cache relations reported by PostgREST (PGRST205)
-- Ensures the optional tables used by EmergencyService exist and are visible.

begin;

-- Emergency admins (optional): used to fetch admin hotline phones.
create table if not exists public.thix_emergency_admins (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  active boolean not null default true,
  priority int not null default 100,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_emergency_admins_active_priority
  on public.thix_emergency_admins(active, priority);

-- Safety ads table should already exist in 20260428_004_emergency_system.sql.
-- We recreate it defensively to support environments where that migration wasn't applied.
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

create index if not exists idx_thix_safety_ads_active
  on public.thix_safety_ads(active, priority);

-- Updated_at triggers (re-use thix_set_updated_at if already defined)
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'thix_set_updated_at'
  ) then
    create function public.thix_set_updated_at() returns trigger as $$
    begin
      new.updated_at = now();
      return new;
    end;
    $$ language plpgsql;
  end if;
end $$;

drop trigger if exists trg_thix_emergency_admins_updated_at on public.thix_emergency_admins;
create trigger trg_thix_emergency_admins_updated_at
before update on public.thix_emergency_admins
for each row execute function public.thix_set_updated_at();

drop trigger if exists trg_thix_safety_ads_updated_at on public.thix_safety_ads;
create trigger trg_thix_safety_ads_updated_at
before update on public.thix_safety_ads
for each row execute function public.thix_set_updated_at();

-- RLS
alter table public.thix_emergency_admins enable row level security;

-- Read-only for authenticated users (so the app can fetch the hotline list).
-- Writes should be done from dashboard/service role.
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_admins' and policyname='admins_select_authenticated'
  ) then
    create policy admins_select_authenticated on public.thix_emergency_admins
      for select to authenticated
      using (true);
  end if;
end $$;

-- Best-effort: ensure tables are in the Realtime publication.
do $$
begin
  begin
    alter publication supabase_realtime add table public.thix_emergency_admins;
  exception when others then
    null;
  end;
  begin
    alter publication supabase_realtime add table public.thix_safety_ads;
  exception when others then
    null;
  end;
  begin
    alter publication supabase_realtime add table public.thix_notifications;
  exception when others then
    null;
  end;
end $$;

-- Force PostgREST schema cache reload if helper exists.
do $$
begin
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'pgrst_schema_reload'
  ) then
    perform public.pgrst_schema_reload();
  end if;
end $$;

commit;
