begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create policy attendance_admin_check_in_receive
on realtime.messages for select to authenticated
using (
  extension = 'broadcast'
  and topic = (select realtime.topic())
  and (select realtime.topic()) =
    'office-check-ins:' || (select public.active_office_id())::text || ':' || (select auth.uid())::text
  and (select public.is_company_admin(public.active_office_id()))
);

create policy attendance_admin_check_in_no_client_send
on realtime.messages as restrictive for insert to anon, authenticated
with check (
  coalesce(topic, '') not like 'office-check-ins:%'
  and coalesce((select realtime.topic()), '') not like 'office-check-ins:%'
);

create schema if not exists attendance_internal;
revoke all on schema attendance_internal from public, anon, authenticated;

create function attendance_internal.notify_office_check_in() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Realtime caches channel authorization. Re-evaluate each recipient here so
  -- a stale channel stops receiving events after demotion or an office switch.
  perform realtime.send(
    case when m.user_id = new.user_id then '{}'::jsonb
         else jsonb_build_object('check_in_id', new.id) end,
    'check_in_saved',
    'office-check-ins:' || new.organization_id::text || ':' || m.user_id::text,
    true
  )
  from public.user_office_preferences p
  join public.memberships m on m.organization_id = p.active_organization_id
    and m.user_id = p.user_id
  where p.active_organization_id = new.organization_id and m.active and m.role = 'admin';
  return new;
exception when others then
  -- Delivery is advisory. Never roll back a check-in for a Realtime failure.
  raise warning 'Attendance check-in notification failed (SQLSTATE %)', sqlstate;
  return new;
end;
$$;

revoke all on function attendance_internal.notify_office_check_in() from public, anon, authenticated;

create trigger attendance_office_check_in_realtime
after insert on public.check_ins for each row
execute function attendance_internal.notify_office_check_in();

commit;
