-- THIX UID generation + payment-gated activation (Supabase)
-- Safe to re-run.

-- 1) Extend profile table with activation state.
alter table if exists public.thix_profiles
  add column if not exists is_active boolean not null default false;

alter table if exists public.thix_profiles
  add column if not exists registration_status text;

alter table if exists public.thix_profiles
  add column if not exists activated_at timestamptz;

-- 2) Payment/audit table.
create table if not exists public.thix_payments (
  id bigserial primary key,
  user_id text not null,
  tx_ref text not null,
  method text,
  amount numeric,
  currency text,
  status text not null default 'paid',
  created_at timestamptz not null default now()
);

create unique index if not exists thix_payments_tx_ref_uq on public.thix_payments (tx_ref);
create index if not exists thix_payments_user_id_idx on public.thix_payments (user_id);

-- 3) Checksum digit (Luhn-like) for anti-typo / anti-fraud.
create or replace function public.thix_uid_checksum_digit(p_input text)
returns int
language plpgsql
as $$
declare
  cleaned text := upper(regexp_replace(coalesce(p_input, ''), '[^A-Z0-9]', '', 'g'));
  digits int[] := array[]::int[];
  i int;
  ch text;
  v int;
  tens int;
  ones int;
  sum int := 0;
  alt boolean := true;
  d int;
begin
  if cleaned = '' then
    return 0;
  end if;

  for i in 1..length(cleaned) loop
    ch := substr(cleaned, i, 1);
    if ch ~ '^[0-9]$' then
      v := ascii(ch) - ascii('0');
    elsif ch ~ '^[A-Z]$' then
      v := 10 + (ascii(ch) - ascii('A'));
    else
      v := 0;
    end if;

    if v >= 10 then
      tens := v / 10;
      ones := v % 10;
      digits := array_append(digits, tens);
      digits := array_append(digits, ones);
    else
      digits := array_append(digits, v);
    end if;
  end loop;

  -- Luhn-like check digit (mod10)
  for i in reverse array_lower(digits, 1)..array_upper(digits, 1) loop
    d := digits[i];
    if alt then
      d := d * 2;
      if d > 9 then d := d - 9; end if;
    end if;
    sum := sum + d;
    alt := not alt;
  end loop;

  return (10 - (sum % 10)) % 10;
end;
$$;

-- 4) Generate a unique THIX UID, checking against thix_profiles(thix_id).
-- Format: THIX-[COUNTRY]-[MMYY]-[RANDOM5]-[CODE3]-[CHECK]
create or replace function public.thix_generate_uid(p_country_code text)
returns text
language plpgsql
as $$
declare
  cc text := upper(substr(coalesce(nullif(trim(p_country_code), ''), 'XX'), 1, 2));
  mm_yy text := to_char(now(), 'MMYY');
  random5 text;
  code3 text;
  body text;
  chk int;
  candidate text;
  attempt int;
begin
  for attempt in 1..80 loop
    random5 := lpad((floor(random() * 100000))::int::text, 5, '0');
    code3 := chr(65 + floor(random() * 26)::int)
          || chr(65 + floor(random() * 26)::int)
          || chr(65 + floor(random() * 26)::int);
    body := 'THIX-' || cc || '-' || mm_yy || '-' || random5 || '-' || code3;
    chk := public.thix_uid_checksum_digit(body);
    candidate := body || '-' || chk::text;

    if not exists(select 1 from public.thix_profiles where thix_id = candidate) then
      return candidate;
    end if;
  end loop;

  raise exception 'Unable to generate a unique THIX UID';
end;
$$;

-- 5) Payment-gated activation RPC.
-- Creates/updates profile, generates UID, marks active, stores payment event.
create or replace function public.thix_activate_account_after_payment(
  p_user_id text,
  p_country_code text,
  p_display_name text,
  p_photo_url text,
  p_method text,
  p_tx_ref text,
  p_amount numeric,
  p_currency text
)
returns text
language plpgsql
as $$
declare
  uid text := trim(coalesce(p_user_id, ''));
  tx text := trim(coalesce(p_tx_ref, ''));
  thix_uid text;
begin
  if uid = '' then
    raise exception 'user_id is required';
  end if;
  if tx = '' then
    raise exception 'tx_ref is required';
  end if;

  -- Idempotency: if payment exists, just return existing profile UID.
  if exists(select 1 from public.thix_payments where tx_ref = tx) then
    select thix_id into thix_uid from public.thix_profiles where user_id = uid;
    if thix_uid is null then
      raise exception 'Payment exists but profile missing';
    end if;
    return thix_uid;
  end if;

  thix_uid := public.thix_generate_uid(p_country_code);

  insert into public.thix_profiles (
    user_id, thix_id, display_name, photo_url, country_or_origin,
    is_active, registration_status, activated_at,
    created_at, updated_at
  ) values (
    uid,
    thix_uid,
    coalesce(nullif(trim(p_display_name), ''), ''),
    nullif(trim(p_photo_url), ''),
    nullif(trim(p_country_code), ''),
    true,
    'verified',
    now(),
    now(),
    now()
  )
  on conflict (user_id) do update set
    thix_id = excluded.thix_id,
    display_name = excluded.display_name,
    photo_url = excluded.photo_url,
    country_or_origin = excluded.country_or_origin,
    is_active = true,
    registration_status = 'verified',
    activated_at = now(),
    updated_at = now();

  insert into public.thix_payments (user_id, tx_ref, method, amount, currency, status)
  values (uid, tx, nullif(trim(p_method), ''), p_amount, nullif(trim(p_currency), ''), 'paid');

  return thix_uid;
end;
$$;
