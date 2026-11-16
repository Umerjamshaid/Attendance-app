begin;

-- New clients send only changed fields. Keep the legacy RPC for old APKs.
create function public.update_office_fields(
  p_organization uuid, p_name text default null,
  p_logo text default null, p_change_logo boolean default false
) returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where organization_id = p_organization
    and user_id = auth.uid() and active and role = 'admin' for share;
  if not found then raise exception 'forbidden'; end if;
  if p_name is not null and length(btrim(p_name)) not between 1 and 100 then
    raise exception 'invalid_input';
  end if;
  if p_change_logo and p_logo is not null and (
    p_logo not like p_organization::text || '/%' or not exists(
      select 1 from storage.objects where bucket_id = 'office-logos' and name = p_logo
    )
  ) then raise exception 'invalid_image'; end if;
  update public.organizations set
    name = case when p_name is not null then btrim(p_name) else name end,
    logo_path = case when p_change_logo then p_logo else logo_path end,
    updated_at = now()
  where id = p_organization;
end;
$$;
revoke all on function public.update_office_fields(uuid,text,text,boolean) from public, anon, authenticated;
grant execute on function public.update_office_fields(uuid,text,text,boolean) to authenticated;

create or replace function public.set_office_role(p_organization uuid, p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_owner uuid; v_target public.memberships;
begin
  select created_by into v_owner from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where organization_id = p_organization and user_id = auth.uid() and role = 'admin' and active for share;
  if not found or v_owner is distinct from auth.uid() or p_organization is distinct from public.active_office_id()
    or p_role not in ('admin','employee') then raise exception 'forbidden'; end if;
  select * into v_target from public.memberships where organization_id = p_organization and user_id = p_user for update;
  if v_target.id is null then raise exception 'forbidden'; end if;
  if p_user = v_owner and p_role <> 'admin' then raise exception 'owner_cannot_demote'; end if;
  if p_role = 'employee' and v_target.role = 'admin' and v_target.active and
    (select count(*) from public.memberships where organization_id = p_organization and role = 'admin' and active) <= 1 then raise exception 'last_admin'; end if;
  update public.memberships set role = p_role, updated_at = now() where id = v_target.id;
end;
$$;

create or replace function public.complete_employee_invitation(p_actor uuid, p_invitation uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_invite public.employee_invitations;
begin
  perform 1 from auth.users where id = p_user for update;
  select * into v_invite from public.employee_invitations where id = p_invitation;
  perform 1 from public.organizations where id = v_invite.organization_id for share;
  select * into v_invite from public.employee_invitations where id = p_invitation for update;
  perform 1 from public.memberships where user_id = p_actor and organization_id = v_invite.organization_id and role = 'admin' and active for share;
  if not found or v_invite.user_id is distinct from p_user then raise exception 'forbidden'; end if;
  if not exists(select 1 from auth.users where id = p_user and lower(email) = lower(v_invite.email)) then raise exception 'forbidden'; end if;
  if v_invite.accepted_at is not null then return; end if;
  update public.employee_invitations set invited_by = p_actor where id = p_invitation;
  if exists(select 1 from public.memberships where user_id = p_user) then return; end if;
  insert into public.memberships(user_id, organization_id, employee_code, department)
    values(p_user, v_invite.organization_id, v_invite.employee_code, v_invite.department);
  insert into public.profiles(user_id, name) values(p_user, v_invite.name) on conflict(user_id) do nothing;
  insert into public.user_office_preferences(user_id, active_organization_id) values(p_user, v_invite.organization_id) on conflict(user_id) do nothing;
  update public.employee_invitations set accepted_at = now() where id = p_invitation;
end;
$$;
commit;
