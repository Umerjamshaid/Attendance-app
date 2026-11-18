begin;

create table public.office_invite_codes (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  invited_by uuid not null references auth.users(id) on delete cascade,
  code_hash bytea not null unique,
  name text not null,
  employee_code text not null,
  department text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  primary key (organization_id, user_id)
);
alter table public.office_invite_codes enable row level security;
revoke all on public.office_invite_codes from public, anon, authenticated;

create function public.create_office_invite_code(
  p_organization uuid, p_email text, p_name text, p_employee_code text, p_department text
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_target uuid;
  -- Select only uniformly random bits from the UUIDs for the 16 base32 characters.
  v_random bytea := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid());
  v_code text;
begin
  perform 1 from public.organizations where id = p_organization for share;
  perform 1 from public.memberships m where m.organization_id = p_organization
    and m.user_id = v_actor and m.role = 'admin' and m.active for share;
  if not found then raise exception 'forbidden'; end if;
  if coalesce(trim(p_name), '') = '' or length(p_name) > 100
    or coalesce(trim(p_department), '') = '' or length(p_department) > 100
    or coalesce(p_employee_code, '') !~ '^[A-Z0-9_-]{1,32}$'
    or coalesce(trim(p_email), '') = '' or length(p_email) > 100 then
    raise exception 'invalid_input';
  end if;
  v_target := public.invitation_user(trim(p_email));
  if v_target is null then raise exception 'office_code_account_required'; end if;
  if exists (select 1 from public.memberships m where m.organization_id = p_organization
    and (m.user_id = v_target or m.employee_code = p_employee_code)) then
    raise exception 'duplicate_employee';
  end if;
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1 + get_byte(v_random, n) % 32, 1), '' order by n)
    into v_code from generate_series(0, 16) as g(n) where n <> 6;
  insert into public.office_invite_codes as c
    (organization_id, user_id, invited_by, code_hash, name, employee_code, department, expires_at)
    values (p_organization, v_target, v_actor, sha256(convert_to(v_code, 'UTF8')),
      trim(p_name), p_employee_code, trim(p_department), now() + interval '24 hours')
    on conflict (organization_id, user_id) do update
    set invited_by = excluded.invited_by, code_hash = excluded.code_hash,
      name = excluded.name, employee_code = excluded.employee_code, department = excluded.department,
      expires_at = excluded.expires_at, used_at = null;
  return concat_ws(' ', substr(v_code, 1, 4), substr(v_code, 5, 4),
    substr(v_code, 9, 4), substr(v_code, 13, 4));
end;
$$;

create function public.redeem_office_invite_code(p_code text) returns uuid
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

  insert into public.memberships(user_id, organization_id, employee_code, department, role)
    values(v_user, v_office, v_invite.employee_code, v_invite.department, 'employee')
    on conflict do nothing;
  if not found then raise exception 'duplicate_employee'; end if;
  insert into public.profiles(user_id, name) values(v_user, v_invite.name)
    on conflict(user_id) do nothing;
  update public.office_invite_codes set used_at = now()
    where organization_id = v_office and user_id = v_user;
  return v_office;
end;
$$;

revoke all on function public.create_office_invite_code(uuid,text,text,text,text),
  public.redeem_office_invite_code(text) from public, anon, authenticated;
grant execute on function public.create_office_invite_code(uuid,text,text,text,text),
  public.redeem_office_invite_code(text) to authenticated;
commit;
