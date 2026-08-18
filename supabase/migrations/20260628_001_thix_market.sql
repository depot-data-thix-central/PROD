-- THIX MARKET core tables

create extension if not exists "pgcrypto";

-- =========================
-- Categories
-- =========================
create table if not exists public.market_categories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  icon_key text null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- Stores
-- =========================
create table if not exists public.market_stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid null references auth.users(id) on delete set null,
  name text not null,
  cover_image_url text null,
  city text null,
  rating numeric not null default 0,
  rating_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- Products
-- =========================
create table if not exists public.market_products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid null references auth.users(id) on delete set null,
  store_id uuid null references public.market_stores(id) on delete set null,
  category_id uuid null references public.market_categories(id) on delete set null,
  title text not null,
  description text null,
  image_url text null,
  currency text not null default 'XOF',
  price int not null default 0,
  old_price int null,
  discount_percent int not null default 0,
  rating numeric not null default 0,
  rating_count int not null default 0,
  is_flash boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists market_products_flash_idx on public.market_products (is_flash, updated_at desc);
create index if not exists market_products_category_idx on public.market_products (category_id, updated_at desc);

-- =========================
-- Lives
-- =========================
create table if not exists public.market_lives (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid null references auth.users(id) on delete set null,
  title text not null,
  host_name text null,
  cover_image_url text null,
  is_live boolean not null default true,
  viewers int not null default 0,
  started_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists market_lives_live_idx on public.market_lives (is_live, started_at desc);

-- =========================
-- RLS
-- =========================
alter table public.market_categories enable row level security;
alter table public.market_stores enable row level security;
alter table public.market_products enable row level security;
alter table public.market_lives enable row level security;

-- Public read access (anon + authenticated)
drop policy if exists "market_categories_read" on public.market_categories;
create policy "market_categories_read" on public.market_categories for select using (true);

drop policy if exists "market_stores_read" on public.market_stores;
create policy "market_stores_read" on public.market_stores for select using (true);

drop policy if exists "market_products_read" on public.market_products;
create policy "market_products_read" on public.market_products for select using (true);

drop policy if exists "market_lives_read" on public.market_lives;
create policy "market_lives_read" on public.market_lives for select using (true);

-- Authenticated write access (basic owner model)
drop policy if exists "market_stores_write" on public.market_stores;
create policy "market_stores_write" on public.market_stores
  for insert to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists "market_stores_update" on public.market_stores;
create policy "market_stores_update" on public.market_stores
  for update to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "market_products_write" on public.market_products;
create policy "market_products_write" on public.market_products
  for insert to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists "market_products_update" on public.market_products;
create policy "market_products_update" on public.market_products
  for update to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "market_lives_write" on public.market_lives;
create policy "market_lives_write" on public.market_lives
  for insert to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists "market_lives_update" on public.market_lives;
create policy "market_lives_update" on public.market_lives
  for update to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Updated_at triggers
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_market_categories_updated_at on public.market_categories;
create trigger trg_market_categories_updated_at before update on public.market_categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_market_stores_updated_at on public.market_stores;
create trigger trg_market_stores_updated_at before update on public.market_stores
for each row execute function public.set_updated_at();

drop trigger if exists trg_market_products_updated_at on public.market_products;
create trigger trg_market_products_updated_at before update on public.market_products
for each row execute function public.set_updated_at();

drop trigger if exists trg_market_lives_updated_at on public.market_lives;
create trigger trg_market_lives_updated_at before update on public.market_lives
for each row execute function public.set_updated_at();
