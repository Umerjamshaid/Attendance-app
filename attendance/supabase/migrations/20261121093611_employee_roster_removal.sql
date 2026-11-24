begin;

-- Keep the membership key: existing check-ins and evidence depend on it.
alter table public.memberships
  add column removed_at timestamptz,
  add constraint removed_employee_has_no_access
    check (removed_at is null or (not active and role = 'employee'));

create or replace function public.company_employees(p_organization uuid) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.employee_code, 'authUserId', m.user_id,
    'organizationId', m.organization_id, 'name', p.name, 'email', u.email,
    'role', m.role, 'department', m.department, 'headline', p.headline, 'chips', p.chips,
    'isActive', m.active, 'isRemoved', m.removed_at is not null, 'time', '')
  from public.memberships m join public.profiles p using(user_id) join auth.users u on u.id = m.user_id
  where m.organization_id = p_organization and public.is_company_admin(p_organization)
    and p_organization = (select public.active_office_id()) order by p.name;
$$;

create function public.remove_office_employee(p_organization uuid, p_employee_code text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_target public.memberships;
  v_owner uuid;
begin
  select created_by into v_owner from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where organization_id = p_organization
    and user_id = auth.uid() and role = 'admin' and active for share;
  if not found or p_organization is distinct from public.active_office_id() then
    raise exception 'forbidden';
  end if;
  select * into v_target from public.memberships where organization_id = p_organization
    and employee_code = p_employee_code for update;
  if not found or v_target.role <> 'employee' or v_target.user_id = auth.uid()
    or v_target.user_id = v_owner then
    raise exception 'forbidden';
  end if;
  if v_target.removed_at is not null then return; end if;
  update public.memberships set active = false, removed_at = now(), updated_at = now()
    where id = v_target.id;
  delete from public.office_invite_codes where organization_id = p_organization
    and user_id = v_target.user_id;
  delete from public.employee_invitations where organization_id = p_organization
    and user_id = v_target.user_id and accepted_at is null;
end;
$$;

create function public.reinvite_removed_employee(p_organization uuid, p_employee_code text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_target public.memberships;
  v_name text;
  -- Same random-bit selection and token format as a regular office code.
  v_random bytea := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid());
  v_code text;
begin
  perform 1 from public.organizations where id = p_organization for share;
  perform 1 from public.memberships where organization_id = p_organization
    and user_id = v_actor and role = 'admin' and active for share;
  if not found or p_organization is distinct from public.active_office_id() then
    raise exception 'forbidden';
  end if;
  select * into v_target from public.memberships where organization_id = p_organization
    and employee_code = p_employee_code and removed_at is not null;
  if not found then raise exception 'employee_not_removed'; end if;
  -- Match redemption's lock order when replacing an outstanding code.
  perform 1 from public.office_invite_codes where organization_id = p_organization
    and user_id = v_target.user_id for update;
  perform 1 from public.memberships where id = v_target.id and removed_at is not null for share;
  if not found then raise exception 'employee_not_removed'; end if;
  select name into v_name from public.profiles where user_id = v_target.user_id;
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1 + get_byte(v_random, n) % 32, 1), '' order by n)
    into v_code from generate_series(0, 16) as g(n) where n <> 6;
  insert into public.office_invite_codes
    (organization_id, user_id, invited_by, code_hash, name, employee_code, department, expires_at)
    values (p_organization, v_target.user_id, v_actor, sha256(convert_to(v_code, 'UTF8')),
      v_name, v_target.employee_code, v_target.department, now() + interval '24 hours')
    on conflict (organization_id, user_id) do update
      set invited_by = excluded.invited_by, code_hash = excluded.code_hash,
        name = excluded.name, employee_code = excluded.employee_code, department = excluded.department,
        expires_at = excluded.expires_at, used_at = null;
  return concat_ws(' ', substr(v_code, 1, 4), substr(v_code, 5, 4),
    substr(v_code, 9, 4), substr(v_code, 13, 4));
end;
$$;

create or replace function public.redeem_office_invite_code(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_code text;
  v_hash bytea;
  v_office uuid;
  v_invite public.office_invite_codes;
begin
  if v_user is null or p_code is null or length(p_code) > 40 then
    raise exception 'invalid_office_code';
  end if;
  v_code := upper(regexp_replace(p_code, '[[:space:]-]', '', 'g'));
  if v_code !~ '^[A-HJ-NP-Z2-9]{16}$' then raise exception 'invalid_office_code'; end if;
  v_hash := sha256(convert_to(v_code, 'UTF8'));
  perform 1 from auth.users where id = v_user and email_confirmed_at is not null for update;
  if not found then raise exception 'invalid_office_code'; end if;
  select organization_id into v_office from public.office_invite_codes
    where code_hash = v_hash and user_id = v_user;
  if not found then raise exception 'invalid_office_code'; end if;
  perform 1 from public.organizations where id = v_office for share;
  select * into v_invite from public.office_invite_codes where organization_id = v_office
    and user_id = v_user and code_hash = v_hash for update;
  if not found or v_invite.expires_at <= now() or v_invite.used_at is not null then
    raise exception 'invalid_office_code';
  end if;
  perform 1 from public.memberships where organization_id = v_office
    and user_id = v_invite.invited_by and role = 'admin' and active for share;
  if not found then raise exception 'invalid_office_code'; end if;

  -- Restore only the exact removed employee, not a paused or active member.
  update public.memberships set active = true, removed_at = null, updated_at = now()
    where organization_id = v_office and user_id = v_user
      and employee_code = v_invite.employee_code and removed_at is not null;
  if not found then
    insert into public.memberships(user_id, organization_id, employee_code, department, role)
      values(v_user, v_office, v_invite.employee_code, v_invite.department, 'employee')
      on conflict do nothing;
    if not found then raise exception 'duplicate_employee'; end if;
  end if;
  insert into public.profiles(user_id, name) values(v_user, v_invite.name)
    on conflict(user_id) do nothing;
  update public.office_invite_codes set used_at = now()
    where organization_id = v_office and user_id = v_user;
  return v_office;
end;
$$;

revoke all on function public.remove_office_employee(uuid,text),
  public.reinvite_removed_employee(uuid,text) from public, anon, authenticated;
grant execute on function public.remove_office_employee(uuid,text),
  public.reinvite_removed_employee(uuid,text) to authenticated;
commit;
