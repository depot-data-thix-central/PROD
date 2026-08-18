-- THIX ID Enterprise Vault + Delegated Authority (scaffold)
-- Date: 2026-05-13

create extension if not exists pgcrypto;

-- ==============================================================
-- Corporate E-Vault
-- ==============================================================
create table if not exists public.thix_enterprise_vault_files (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  uploaded_by uuid references auth.users(id) on delete set null,
  category text not null,
  title text not null,
  storage_bucket text not null default 'enterprise_vault',
  storage_path text not null,
  mime_type text,
  size_bytes bigint,
  sha256 text,
  encrypted_key text,
  integrity_verified boolean not null default false,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_enterprise_vault_company on public.thix_enterprise_vault_files(company_id, created_at desc);

-- ==============================================================
-- Delegated authority / mandates
-- ==============================================================
create table if not exists public.thix_enterprise_delegations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.thix_enterprise_companies(id) on delete cascade,
  granted_by uuid not null references auth.users(id) on delete cascade,
  granted_to uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  permissions jsonb not null default '{}'::jsonb,
  financial_limit numeric,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_thix_enterprise_delegations_company on public.thix_enterprise_delegations(company_id, created_at desc);
create index if not exists idx_thix_enterprise_delegations_to on public.thix_enterprise_delegations(granted_to);

-- ==============================================================
-- RLS
-- ==============================================================
alter table public.thix_enterprise_vault_files enable row level security;
alter table public.thix_enterprise_delegations enable row level security;

drop policy if exists "enterprise_vault_select" on public.thix_enterprise_vault_files;
create policy "enterprise_vault_select"
on public.thix_enterprise_vault_files
for select
using (public.thix_is_enterprise_member(company_id));

drop policy if exists "enterprise_vault_insert" on public.thix_enterprise_vault_files;
create policy "enterprise_vault_insert"
on public.thix_enterprise_vault_files
for insert
with check (public.thix_is_enterprise_member(company_id) and uploaded_by = auth.uid());

drop policy if exists "enterprise_delegations_select" on public.thix_enterprise_delegations;
create policy "enterprise_delegations_select"
on public.thix_enterprise_delegations
for select
using (public.thix_is_enterprise_member(company_id));

drop policy if exists "enterprise_delegations_insert" on public.thix_enterprise_delegations;
create policy "enterprise_delegations_insert"
on public.thix_enterprise_delegations
for insert
with check (public.thix_is_enterprise_member(company_id) and granted_by = auth.uid());

-- updated_at triggers reuse thix_set_updated_at()
drop trigger if exists trg_thix_enterprise_vault_updated_at on public.thix_enterprise_vault_files;
create trigger trg_thix_enterprise_vault_updated_at before update on public.thix_enterprise_vault_files
for each row execute procedure public.thix_set_updated_at();

drop trigger if exists trg_thix_enterprise_delegations_updated_at on public.thix_enterprise_delegations;
create trigger trg_thix_enterprise_delegations_updated_at before update on public.thix_enterprise_delegations
for each row execute procedure public.thix_set_updated_at();
