-- THIX ID Emergency Actions: evidence + metadata

-- Adds flexible metadata and evidence attachments to emergency alerts.

alter table public.thix_emergency_alerts
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists public.thix_emergency_evidence (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.thix_emergency_alerts(id) on delete cascade,
  kind text not null, -- image|audio|document|video|other
  storage_path text not null,
  mime_type text,
  file_name text,
  file_size_bytes bigint,
  created_at timestamptz not null default now()
);

create index if not exists idx_thix_emergency_evidence_alert on public.thix_emergency_evidence (alert_id, created_at desc);

alter table public.thix_emergency_evidence enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_evidence' and policyname='evidence_select_via_alert'
  ) then
    create policy evidence_select_via_alert on public.thix_emergency_evidence
      for select to authenticated
      using (
        exists (
          select 1 from public.thix_emergency_alerts a
          where a.id = thix_emergency_evidence.alert_id
            and a.user_id = auth.uid()::text
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='thix_emergency_evidence' and policyname='evidence_insert_via_alert'
  ) then
    create policy evidence_insert_via_alert on public.thix_emergency_evidence
      for insert to authenticated
      with check (
        exists (
          select 1 from public.thix_emergency_alerts a
          where a.id = thix_emergency_evidence.alert_id
            and a.user_id = auth.uid()::text
        )
      );
  end if;
end $$;

-- Realtime publication (best-effort)
do $$
begin
  begin
    alter publication supabase_realtime add table public.thix_emergency_evidence;
  exception when others then
    null;
  end;
end $$;
