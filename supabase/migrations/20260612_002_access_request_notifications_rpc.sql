-- RPC bridge for strict-RLS workflows:
-- - Viewer requests access to a profile
-- - Owner approves/rejects
-- - Notifications are emitted server-side (reliable + realtime)

create or replace function public.thix_request_profile_access(
  p_target_user_id text,
  p_message text default null,
  p_thix_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request_id uuid;
  v_requester text;
  v_target_uuid uuid;
begin
  v_requester := auth.uid()::text;
  if v_requester is null then
    raise exception 'not_authenticated';
  end if;

  if p_target_user_id is null or length(trim(p_target_user_id)) = 0 then
    raise exception 'target_required';
  end if;

  -- Try to cast to uuid for notifications.
  begin
    v_target_uuid := p_target_user_id::uuid;
  exception when others then
    v_target_uuid := null;
  end;

  insert into public.thix_access_requests(requester_id, target_user_id, status, message)
  values (v_requester, p_target_user_id, 'pending', nullif(trim(coalesce(p_message, '')), ''))
  on conflict (requester_id, target_user_id)
  do update set
    status = 'pending',
    message = excluded.message,
    updated_at = now()
  returning id into v_request_id;

  -- Emit notification to target (if target is a real auth.user UUID)
  if v_target_uuid is not null then
    insert into public.thix_notifications(user_id, type, title, body, data)
    values (
      v_target_uuid,
      'access_request',
      'Nouvelle demande d’accès',
      'Un utilisateur souhaite accéder à votre profil THIX.',
      jsonb_build_object(
        'request_id', v_request_id::text,
        'requester_id', v_requester,
        'target_user_id', p_target_user_id,
        'thix_id', coalesce(p_thix_id, '')
      )
    );
  end if;

  return v_request_id;
end;
$$;

revoke all on function public.thix_request_profile_access(text, text, text) from public;
grant execute on function public.thix_request_profile_access(text, text, text) to authenticated;


create or replace function public.thix_set_access_request_status(
  p_request_id text,
  p_new_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner text;
  v_requester text;
  v_target text;
  v_requester_uuid uuid;
  v_request_uuid uuid;
begin
  v_owner := auth.uid()::text;
  if v_owner is null then
    raise exception 'not_authenticated';
  end if;

  if p_request_id is null or length(trim(p_request_id)) = 0 then
    raise exception 'request_id_required';
  end if;

  begin
    v_request_uuid := p_request_id::uuid;
  exception when others then
    raise exception 'invalid_request_id';
  end;

  if p_new_status not in ('approved','rejected','pending') then
    raise exception 'invalid_status';
  end if;

  select requester_id, target_user_id into v_requester, v_target
  from public.thix_access_requests
  where id = v_request_uuid;

  if v_target is null then
    raise exception 'not_found';
  end if;

  if v_target <> v_owner then
    raise exception 'not_allowed';
  end if;

  update public.thix_access_requests
  set status = p_new_status, updated_at = now()
  where id = v_request_uuid;

  begin
    v_requester_uuid := v_requester::uuid;
  exception when others then
    v_requester_uuid := null;
  end;

  if v_requester_uuid is not null then
    insert into public.thix_notifications(user_id, type, title, body, data)
    values (
      v_requester_uuid,
      'access_request',
      case when p_new_status = 'approved' then 'Accès approuvé' else 'Accès refusé' end,
      case when p_new_status = 'approved' then 'Votre demande d’accès a été approuvée.' else 'Votre demande d’accès a été refusée.' end,
      jsonb_build_object('request_id', p_request_id, 'status', p_new_status)
    );
  end if;
end;
$$;

revoke all on function public.thix_set_access_request_status(text, text) from public;
grant execute on function public.thix_set_access_request_status(text, text) to authenticated;
