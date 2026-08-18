-- GEO CATALOG (RDC) - normalized location hierarchy
-- Safe to re-run (idempotent inserts via ON CONFLICT).

create table if not exists public.geo_countries (
  id text primary key,
  name text not null,
  iso2 text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists geo_countries_iso2_uidx on public.geo_countries (iso2);

create table if not exists public.geo_provinces (
  id text primary key,
  country_id text not null references public.geo_countries(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(country_id, name)
);

create index if not exists geo_provinces_country_id_idx on public.geo_provinces (country_id);

create table if not exists public.geo_cities (
  id text primary key,
  province_id text not null references public.geo_provinces(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(province_id, name)
);

create index if not exists geo_cities_province_id_idx on public.geo_cities (province_id);
create index if not exists geo_cities_name_idx on public.geo_cities (name);

create table if not exists public.geo_territories (
  id text primary key,
  province_id text not null references public.geo_provinces(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(province_id, name)
);

create index if not exists geo_territories_province_id_idx on public.geo_territories (province_id);
create index if not exists geo_territories_name_idx on public.geo_territories (name);

create table if not exists public.geo_communes (
  id text primary key,
  city_id text not null references public.geo_cities(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(city_id, name)
);

create index if not exists geo_communes_city_id_idx on public.geo_communes (city_id);
create index if not exists geo_communes_name_idx on public.geo_communes (name);

-- RLS: this is a read-mostly catalog. Allow public read, prevent public writes.
alter table public.geo_countries enable row level security;
alter table public.geo_provinces enable row level security;
alter table public.geo_cities enable row level security;
alter table public.geo_territories enable row level security;
alter table public.geo_communes enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='geo_countries' and policyname='geo_countries_read') then
    create policy geo_countries_read on public.geo_countries for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='geo_provinces' and policyname='geo_provinces_read') then
    create policy geo_provinces_read on public.geo_provinces for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='geo_cities' and policyname='geo_cities_read') then
    create policy geo_cities_read on public.geo_cities for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='geo_territories' and policyname='geo_territories_read') then
    create policy geo_territories_read on public.geo_territories for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='geo_communes' and policyname='geo_communes_read') then
    create policy geo_communes_read on public.geo_communes for select using (true);
  end if;
end $$;

-- Seed: COUNTRY
insert into public.geo_countries (id, name, iso2)
values ('cd', 'Democratic Republic of Congo', 'CD')
on conflict (id) do update set name=excluded.name, iso2=excluded.iso2, updated_at=now();

-- Seed: PROVINCES (26)
insert into public.geo_provinces (id, country_id, name)
values
  ('cd-kinshasa', 'cd', 'Kinshasa'),
  ('cd-kongo-central', 'cd', 'Kongo Central'),
  ('cd-kwango', 'cd', 'Kwango'),
  ('cd-kwilu', 'cd', 'Kwilu'),
  ('cd-mai-ndombe', 'cd', 'Mai-Ndombe'),
  ('cd-kasai', 'cd', 'Kasaï'),
  ('cd-kasai-central', 'cd', 'Kasaï Central'),
  ('cd-kasai-oriental', 'cd', 'Kasaï Oriental'),
  ('cd-lomami', 'cd', 'Lomami'),
  ('cd-sankuru', 'cd', 'Sankuru'),
  ('cd-sud-ubangi', 'cd', 'Sud-Ubangi'),
  ('cd-nord-ubangi', 'cd', 'Nord-Ubangi'),
  ('cd-mongala', 'cd', 'Mongala'),
  ('cd-tshuapa', 'cd', 'Tshuapa'),
  ('cd-equateur', 'cd', 'Équateur'),
  ('cd-tshopo', 'cd', 'Tshopo'),
  ('cd-bas-uele', 'cd', 'Bas-Uele'),
  ('cd-haut-uele', 'cd', 'Haut-Uele'),
  ('cd-ituri', 'cd', 'Ituri'),
  ('cd-nord-kivu', 'cd', 'Nord-Kivu'),
  ('cd-sud-kivu', 'cd', 'Sud-Kivu'),
  ('cd-maniema', 'cd', 'Maniema'),
  ('cd-tanganyika', 'cd', 'Tanganyika'),
  ('cd-haut-lomami', 'cd', 'Haut-Lomami'),
  ('cd-lualaba', 'cd', 'Lualaba'),
  ('cd-haut-katanga', 'cd', 'Haut-Katanga')
on conflict (id) do update set name=excluded.name, country_id=excluded.country_id, updated_at=now();

-- Seed: CITIES (principales)
insert into public.geo_cities (id, province_id, name)
values
  ('cd-kinshasa-kinshasa', 'cd-kinshasa', 'Kinshasa'),
  ('cd-haut-katanga-lubumbashi', 'cd-haut-katanga', 'Lubumbashi'),
  ('cd-kasai-oriental-mbuji-mayi', 'cd-kasai-oriental', 'Mbuji-Mayi'),
  ('cd-kasai-central-kananga', 'cd-kasai-central', 'Kananga'),
  ('cd-tshopo-kisangani', 'cd-tshopo', 'Kisangani'),
  ('cd-sud-kivu-bukavu', 'cd-sud-kivu', 'Bukavu'),
  ('cd-nord-kivu-goma', 'cd-nord-kivu', 'Goma'),
  ('cd-kongo-central-matadi', 'cd-kongo-central', 'Matadi'),
  ('cd-lualaba-kolwezi', 'cd-lualaba', 'Kolwezi'),
  ('cd-haut-katanga-likasi', 'cd-haut-katanga', 'Likasi'),
  ('cd-kwilu-kikwit', 'cd-kwilu', 'Kikwit'),
  ('cd-kasai-tshikapa', 'cd-kasai', 'Tshikapa'),
  ('cd-ituri-bunia', 'cd-ituri', 'Bunia'),
  ('cd-sud-kivu-uvira', 'cd-sud-kivu', 'Uvira'),
  ('cd-nord-kivu-beni', 'cd-nord-kivu', 'Beni'),
  ('cd-nord-kivu-butembo', 'cd-nord-kivu', 'Butembo'),
  ('cd-tanganyika-kalemie', 'cd-tanganyika', 'Kalemie'),
  ('cd-sud-ubangi-gemena', 'cd-sud-ubangi', 'Gemena'),
  ('cd-mongala-lisala', 'cd-mongala', 'Lisala'),
  ('cd-equateur-mbandaka', 'cd-equateur', 'Mbandaka')
on conflict (id) do update set name=excluded.name, province_id=excluded.province_id, updated_at=now();

-- Seed: TERRITORIES (par province - exemples fournis)
insert into public.geo_territories (id, province_id, name)
values
  ('cd-nord-kivu-beni', 'cd-nord-kivu', 'Beni'),
  ('cd-nord-kivu-lubero', 'cd-nord-kivu', 'Lubero'),
  ('cd-nord-kivu-rutshuru', 'cd-nord-kivu', 'Rutshuru'),
  ('cd-nord-kivu-masisi', 'cd-nord-kivu', 'Masisi'),
  ('cd-nord-kivu-walikale', 'cd-nord-kivu', 'Walikale'),

  ('cd-sud-kivu-fizi', 'cd-sud-kivu', 'Fizi'),
  ('cd-sud-kivu-uvira', 'cd-sud-kivu', 'Uvira'),
  ('cd-sud-kivu-kabare', 'cd-sud-kivu', 'Kabare'),
  ('cd-sud-kivu-kalehe', 'cd-sud-kivu', 'Kalehe'),
  ('cd-sud-kivu-walungu', 'cd-sud-kivu', 'Walungu'),

  ('cd-ituri-aru', 'cd-ituri', 'Aru'),
  ('cd-ituri-djugu', 'cd-ituri', 'Djugu'),
  ('cd-ituri-irumu', 'cd-ituri', 'Irumu'),
  ('cd-ituri-mambasa', 'cd-ituri', 'Mambasa'),

  ('cd-kongo-central-lukula', 'cd-kongo-central', 'Lukula'),
  ('cd-kongo-central-mbanza-ngungu', 'cd-kongo-central', 'Mbanza-Ngungu'),
  ('cd-kongo-central-madimba', 'cd-kongo-central', 'Madimba'),
  ('cd-kongo-central-songololo', 'cd-kongo-central', 'Songololo'),
  ('cd-kongo-central-seke-banza', 'cd-kongo-central', 'Seke-Banza'),

  ('cd-kwilu-bulungu', 'cd-kwilu', 'Bulungu'),
  ('cd-kwilu-gungu', 'cd-kwilu', 'Gungu'),
  ('cd-kwilu-idiofa', 'cd-kwilu', 'Idiofa'),
  ('cd-kwilu-masimanimba', 'cd-kwilu', 'Masimanimba'),

  ('cd-kwango-kenge', 'cd-kwango', 'Kenge'),
  ('cd-kwango-feshi', 'cd-kwango', 'Feshi'),
  ('cd-kwango-kahemba', 'cd-kwango', 'Kahemba'),
  ('cd-kwango-kasongo-lunda', 'cd-kwango', 'Kasongo-Lunda'),

  ('cd-lualaba-dilolo', 'cd-lualaba', 'Dilolo'),
  ('cd-lualaba-lubudi', 'cd-lualaba', 'Lubudi'),
  ('cd-lualaba-mutshatsha', 'cd-lualaba', 'Mutshatsha'),
  ('cd-lualaba-kapanga', 'cd-lualaba', 'Kapanga'),

  ('cd-haut-katanga-kasenga', 'cd-haut-katanga', 'Kasenga'),
  ('cd-haut-katanga-kipushi', 'cd-haut-katanga', 'Kipushi'),
  ('cd-haut-katanga-mitwaba', 'cd-haut-katanga', 'Mitwaba'),
  ('cd-haut-katanga-pweto', 'cd-haut-katanga', 'Pweto'),
  ('cd-haut-katanga-sakania', 'cd-haut-katanga', 'Sakania')
on conflict (id) do update set name=excluded.name, province_id=excluded.province_id, updated_at=now();

-- Seed: COMMUNES (Kinshasa - exemples)
insert into public.geo_communes (id, city_id, name)
values
  ('cd-kinshasa-kinshasa-bandalungwa', 'cd-kinshasa-kinshasa', 'Bandalungwa'),
  ('cd-kinshasa-kinshasa-barumbu', 'cd-kinshasa-kinshasa', 'Barumbu'),
  ('cd-kinshasa-kinshasa-bumbu', 'cd-kinshasa-kinshasa', 'Bumbu'),
  ('cd-kinshasa-kinshasa-gombe', 'cd-kinshasa-kinshasa', 'Gombe'),
  ('cd-kinshasa-kinshasa-kalamu', 'cd-kinshasa-kinshasa', 'Kalamu'),
  ('cd-kinshasa-kinshasa-kasa-vubu', 'cd-kinshasa-kinshasa', 'Kasa-Vubu'),
  ('cd-kinshasa-kinshasa-kimbanseke', 'cd-kinshasa-kinshasa', 'Kimbanseke'),
  ('cd-kinshasa-kinshasa-kinshasa', 'cd-kinshasa-kinshasa', 'Kinshasa'),
  ('cd-kinshasa-kinshasa-kintambo', 'cd-kinshasa-kinshasa', 'Kintambo'),
  ('cd-kinshasa-kinshasa-lemba', 'cd-kinshasa-kinshasa', 'Lemba'),
  ('cd-kinshasa-kinshasa-limete', 'cd-kinshasa-kinshasa', 'Limete'),
  ('cd-kinshasa-kinshasa-lingwala', 'cd-kinshasa-kinshasa', 'Lingwala'),
  ('cd-kinshasa-kinshasa-makala', 'cd-kinshasa-kinshasa', 'Makala'),
  ('cd-kinshasa-kinshasa-maluku', 'cd-kinshasa-kinshasa', 'Maluku'),
  ('cd-kinshasa-kinshasa-masina', 'cd-kinshasa-kinshasa', 'Masina'),
  ('cd-kinshasa-kinshasa-matete', 'cd-kinshasa-kinshasa', 'Matete'),
  ('cd-kinshasa-kinshasa-mont-ngafula', 'cd-kinshasa-kinshasa', 'Mont Ngafula'),
  ('cd-kinshasa-kinshasa-ndjili', 'cd-kinshasa-kinshasa', 'Ndjili'),
  ('cd-kinshasa-kinshasa-ngaba', 'cd-kinshasa-kinshasa', 'Ngaba'),
  ('cd-kinshasa-kinshasa-ngaliema', 'cd-kinshasa-kinshasa', 'Ngaliema'),
  ('cd-kinshasa-kinshasa-nsele', 'cd-kinshasa-kinshasa', 'Nsele')
on conflict (id) do update set name=excluded.name, city_id=excluded.city_id, updated_at=now();
