-- Forward-only expansion. Deploy with the office-aware Edge Functions and client.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

alter table public.organizations
  add column logo_path text,
  add column created_by uuid references auth.users(id) on delete set null,
  add column updated_at timestamptz not null default now();
-- Legacy rows have no trustworthy creator history. Leave ownership unset until
-- the project owner assigns it explicitly; never infer new privileges by age.
alter table public.memberships
  add column id uuid not null default gen_random_uuid(),
  add column updated_at timestamptz not null default now();

-- Repoint the two user-only dependencies before replacing the old primary key.
alter table public.profiles drop constraint profiles_user_id_fkey;
alter table public.profiles add constraint profiles_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;
alter table public.submission_attempts add column organization_id uuid;
update public.submission_attempts a set organization_id = m.organization_id
  from public.memberships m where m.user_id = a.user_id;
alter table public.submission_attempts alter column organization_id set not null;
alter table public.submission_attempts drop constraint submission_attempts_user_id_fkey;
alter table public.submission_attempts drop constraint submission_attempts_pkey;
alter table public.submission_attempts add primary key (organization_id, user_id, request_id);
alter table public.submission_attempts add constraint submission_attempts_membership_fkey
  foreign key (organization_id, user_id) references public.memberships(organization_id, user_id);
alter table public.memberships drop constraint memberships_pkey;
alter table public.memberships add primary key (id);
create index memberships_user_active_org on public.memberships(user_id, active, organization_id);
create index organizations_creator on public.organizations(created_by);
create index check_ins_office_owner_time on public.check_ins(organization_id, user_id, received_at desc, id);

create table public.user_office_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_organization_id uuid not null,
  updated_at timestamptz not null default now(),
  foreign key (active_organization_id, user_id) references public.memberships(organization_id, user_id)
);
create index office_preferences_membership on public.user_office_preferences(active_organization_id, user_id);
insert into public.user_office_preferences(user_id, active_organization_id)
  select user_id, organization_id from public.memberships where active;
alter table public.user_office_preferences enable row level security;
revoke all on public.user_office_preferences from anon, authenticated;
grant select on public.user_office_preferences to authenticated;
grant all on public.user_office_preferences to service_role;
create policy own_office_preference on public.user_office_preferences for select to authenticated
  using (user_id = (select auth.uid()) and public.is_company_member(active_organization_id));

alter table public.employee_invitations
  add column invited_by uuid references auth.users(id) on delete set null,
  add column accepted_at timestamptz;
update public.employee_invitations i set accepted_at = i.created_at where exists (
  select 1 from public.memberships m where m.organization_id = i.organization_id
  and m.user_id = i.user_id and m.employee_code = i.employee_code
);
create index invitations_pending_user on public.employee_invitations(user_id) where accepted_at is null;
create index invitations_inviter on public.employee_invitations(invited_by);

-- Legacy clients are safe only while a user has exactly one active office.
create function public.single_office_for(p_user uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_org uuid; v_count integer;
begin
  select count(*), min(organization_id::text)::uuid into v_count, v_org
    from public.memberships where user_id = p_user and active;
  if v_count > 1 then raise exception 'office_required'; end if;
  return v_org;
end;
$$;
create function public.active_office_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.active_organization_id from public.user_office_preferences p
  join public.memberships m on m.organization_id = p.active_organization_id and m.user_id = p.user_id
  where p.user_id = (select auth.uid()) and m.active;
$$;

drop policy member_read on public.memberships;
create policy member_read on public.memberships for select to authenticated using (
  public.is_company_member(organization_id) and
  (user_id = (select auth.uid()) or (organization_id = (select public.active_office_id()) and public.is_company_admin(organization_id)))
);
drop policy profile_read on public.profiles;
create policy profile_read on public.profiles for select to authenticated using (
  (user_id = (select auth.uid()) and exists(select 1 from public.memberships m where m.user_id = profiles.user_id and m.active))
  or exists(select 1 from public.memberships m where m.user_id = profiles.user_id
    and m.organization_id = (select public.active_office_id()) and public.is_company_admin(m.organization_id))
);
drop policy check_ins_read on public.check_ins;
create policy check_ins_read on public.check_ins for select to authenticated using (
  organization_id = (select public.active_office_id()) and public.is_company_member(organization_id)
  and (user_id = (select auth.uid()) or public.is_company_admin(organization_id))
);
drop policy evidence_admin_read on public.attendance_evidence;
create policy evidence_admin_read on public.attendance_evidence for select to authenticated using (
  organization_id = (select public.active_office_id()) and public.is_company_admin(organization_id) and expires_at > now()
);

create function public.current_employee(p_organization uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.employee_code, 'authUserId', m.user_id,
    'organizationId', m.organization_id, 'officeName', o.name, 'name', p.name,
    'email', u.email, 'role', m.role, 'department', m.department,
    'headline', p.headline, 'chips', p.chips, 'isActive', m.active, 'time', '')
  from public.memberships m join public.profiles p using(user_id)
  join auth.users u on u.id = m.user_id join public.organizations o on o.id = m.organization_id
  where m.user_id = (select auth.uid()) and m.active and m.organization_id = p_organization
    and p_organization = (select public.active_office_id());
$$;
create or replace function public.current_employee() returns jsonb
language sql stable security definer set search_path = '' as $$
  select public.current_employee(public.single_office_for((select auth.uid())));
$$;
create function public.resolve_office_context() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_org uuid;
begin
  if auth.uid() is null then raise exception 'forbidden'; end if;
  -- Serialize preference repair with explicit switches on every device.
  perform 1 from auth.users where id = auth.uid() for update;
  v_org := public.active_office_id();
  if v_org is null then
    select organization_id into v_org from public.memberships
      where user_id = auth.uid() and active order by created_at, organization_id limit 1 for share;
    if v_org is null then return null; end if;
    insert into public.user_office_preferences(user_id, active_organization_id) values (auth.uid(), v_org)
      on conflict(user_id) do update set active_organization_id = excluded.active_organization_id, updated_at = now();
  end if;
  return public.current_employee(v_org);
end;
$$;
create function public.switch_office(p_organization uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from auth.users where id = auth.uid() for update;
  perform 1 from public.memberships where user_id = auth.uid() and organization_id = p_organization and active for share;
  if not found then raise exception 'inactive'; end if;
  insert into public.user_office_preferences(user_id, active_organization_id) values (auth.uid(), p_organization)
    on conflict(user_id) do update set active_organization_id = excluded.active_organization_id, updated_at = now();
  return public.current_employee(p_organization);
end;
$$;
create function public.my_offices() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', o.id, 'name', o.name, 'logo_path', o.logo_path,
    'role', m.role, 'created_by', o.created_by)
  from public.organizations o join public.memberships m on m.organization_id = o.id
  where m.user_id = (select auth.uid()) and m.active order by o.name, o.id;
$$;
create function public.create_office(p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_org uuid;
begin
  perform 1 from public.memberships where user_id = auth.uid() and role = 'admin' and active for share;
  if not found then raise exception 'forbidden'; end if;
  if length(btrim(p_name)) not between 1 and 100 then raise exception 'invalid_input'; end if;
  insert into public.organizations(name, created_by) values (btrim(p_name), auth.uid()) returning id into v_org;
  insert into public.memberships(organization_id, user_id, employee_code, role, department)
    values (v_org, auth.uid(), 'ADMIN001', 'admin', 'Administration');
  return v_org;
end;
$$;
create function public.update_office(p_organization uuid, p_name text, p_logo text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where organization_id = p_organization and user_id = auth.uid() and active and role = 'admin' for share;
  if not found then raise exception 'forbidden'; end if;
  if length(btrim(p_name)) not between 1 and 100 then raise exception 'invalid_input'; end if;
  if p_logo is not null and (p_logo not like p_organization::text || '/%'
    or not exists(select 1 from storage.objects where bucket_id = 'office-logos' and name = p_logo)) then raise exception 'invalid_image'; end if;
  update public.organizations set name = btrim(p_name), logo_path = p_logo, updated_at = now() where id = p_organization;
end;
$$;

create function public.company_employees(p_organization uuid) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.employee_code, 'authUserId', m.user_id,
    'organizationId', m.organization_id, 'name', p.name, 'email', u.email,
    'role', m.role, 'department', m.department, 'headline', p.headline, 'chips', p.chips, 'isActive', m.active, 'time', '')
  from public.memberships m join public.profiles p using(user_id) join auth.users u on u.id = m.user_id
  where m.organization_id = p_organization and public.is_company_admin(p_organization)
    and p_organization = (select public.active_office_id()) order by p.name;
$$;
create or replace function public.company_employees() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select * from public.company_employees(public.single_office_for((select auth.uid())));
$$;
create function public.save_attendance_policy(p_organization uuid, p_mode text, p_start integer, p_end integer) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where organization_id = p_organization and user_id = auth.uid() and role = 'admin' and active for share;
  if not found or p_organization is distinct from public.active_office_id() then raise exception 'forbidden'; end if;
  update public.organizations set window_mode = p_mode, start_hour = p_start, end_hour = p_end, updated_at = now() where id = p_organization;
end;
$$;
create or replace function public.save_attendance_policy(p_mode text, p_start integer, p_end integer) returns void
language sql security definer set search_path = '' as $$
  select public.save_attendance_policy(public.single_office_for((select auth.uid())), p_mode, p_start, p_end);
$$;
create function public.set_employee_active(p_actor uuid, p_organization uuid, p_code text, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare v_target public.memberships;
begin
  perform 1 from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where user_id = p_actor and organization_id = p_organization and role = 'admin' and active for share;
  if not found then raise exception 'forbidden'; end if;
  select * into v_target from public.memberships where organization_id = p_organization and employee_code = p_code for update;
  if v_target.user_id is null then raise exception 'forbidden'; end if;
  if not p_active and v_target.role = 'admin' and v_target.active and
    (select count(*) from public.memberships where organization_id = p_organization and role = 'admin' and active) <= 1 then raise exception 'last_admin'; end if;
  update public.memberships set active = p_active, updated_at = now() where id = v_target.id;
end;
$$;
create or replace function public.set_employee_active(p_actor uuid, p_code text, p_active boolean) returns void
language sql security definer set search_path = '' as $$
  select public.set_employee_active(p_actor, public.single_office_for(p_actor), p_code, p_active);
$$;
-- Keep role promotion with the office owner, rather than every invited admin.
create function public.set_office_role(p_organization uuid, p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_owner uuid; v_target public.memberships;
begin
  select created_by into v_owner from public.organizations where id = p_organization for update;
  perform 1 from public.memberships where organization_id = p_organization and user_id = auth.uid() and role = 'admin' and active for share;
  if not found or v_owner is distinct from auth.uid() or p_organization is distinct from public.active_office_id()
    or p_role not in ('admin','employee') then raise exception 'forbidden'; end if;
  select * into v_target from public.memberships where organization_id = p_organization and user_id = p_user for update;
  if v_target.id is null then raise exception 'forbidden'; end if;
  if p_role = 'employee' and v_target.role = 'admin' and v_target.active and
    (select count(*) from public.memberships where organization_id = p_organization and role = 'admin' and active) <= 1 then raise exception 'last_admin'; end if;
  update public.memberships set role = p_role, updated_at = now() where id = v_target.id;
end;
$$;

create function public.claim_submission(p_organization uuid, p_user uuid, p_request uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  if not exists(select 1 from public.memberships where organization_id = p_organization and user_id = p_user and active) then raise exception 'inactive'; end if;
  insert into public.submission_attempts(organization_id, user_id, request_id, lease_until) values (p_organization, p_user, p_request, now() + interval '90 seconds')
  on conflict(organization_id, user_id, request_id) do update set lease_until = excluded.lease_until where public.submission_attempts.lease_until < now();
  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$$;
create or replace function public.claim_submission(p_user uuid, p_request uuid) returns boolean
language sql security definer set search_path = '' as $$
  select public.claim_submission(public.single_office_for(p_user), p_user, p_request);
$$;
create function public.finalize_check_in(p_organization uuid, p_user uuid, p_request uuid, p_captured timestamptz, p_device text, p_photo text, p_lat double precision, p_lng double precision, p_accuracy double precision, p_installation uuid, p_platform text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_member public.memberships; v_org public.organizations; v_record public.check_ins; v_local timestamp;
begin
  -- Consistent organization -> membership lock order with policy/access changes.
  select * into v_org from public.organizations where id = p_organization for share;
  select * into v_member from public.memberships where organization_id = p_organization and user_id = p_user and active for share;
  if v_member.id is null then raise exception 'inactive'; end if;
  select * into v_record from public.check_ins where organization_id = p_organization and user_id = p_user and request_id = p_request;
  if v_record.id is not null then return to_jsonb(v_record); end if;
  v_local := now() at time zone v_org.timezone;
  if v_org.window_mode = 'period' and (extract(hour from v_local) < v_org.start_hour or extract(hour from v_local) >= v_org.end_hour) then raise exception 'window_closed'; end if;
  if p_photo <> p_organization::text || '/' || p_user::text || '/' || p_request::text then raise exception 'forbidden'; end if;
  if not exists(select 1 from storage.objects where bucket_id = 'attendance-evidence' and name = p_photo) then raise exception 'missing_photo'; end if;
  insert into public.check_ins(organization_id, user_id, employee_code, request_id, captured_at, company_day, device_model)
    values(p_organization, p_user, v_member.employee_code, p_request, p_captured, v_local::date, p_device)
    on conflict(organization_id, user_id, request_id) do nothing returning * into v_record;
  if v_record.id is null then
    select * into v_record from public.check_ins where organization_id = p_organization and user_id = p_user and request_id = p_request;
    return to_jsonb(v_record);
  end if;
  insert into public.attendance_evidence(check_in_id, organization_id, photo_path, latitude, longitude, accuracy, installation_id, platform)
    values(v_record.id, p_organization, p_photo, p_lat, p_lng, p_accuracy, p_installation, p_platform);
  delete from public.submission_attempts where organization_id = p_organization and user_id = p_user and request_id = p_request;
  return to_jsonb(v_record);
end;
$$;
create or replace function public.finalize_check_in(p_user uuid, p_request uuid, p_captured timestamptz, p_device text, p_photo text, p_lat double precision, p_lng double precision, p_accuracy double precision, p_installation uuid, p_platform text) returns jsonb
language sql security definer set search_path = '' as $$
  select public.finalize_check_in(public.single_office_for(p_user), p_user, p_request, p_captured, p_device, p_photo, p_lat, p_lng, p_accuracy, p_installation, p_platform);
$$;

-- Auth lookup is service-only; never expose an email directory to Flutter.
create function public.invitation_user(p_email text) returns uuid
language sql stable security definer set search_path = '' as $$
  select id from auth.users where lower(email) = lower(p_email) and email_confirmed_at is not null;
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
  update public.employee_invitations set invited_by = coalesce(invited_by, p_actor) where id = p_invitation;
  if v_invite.accepted_at is not null then return; end if;
  -- Existing accounts accept explicitly in-app. New invitees retain first-login setup.
  if exists(select 1 from public.memberships where user_id = p_user) then return; end if;
  insert into public.memberships(user_id, organization_id, employee_code, department)
    values(p_user, v_invite.organization_id, v_invite.employee_code, v_invite.department);
  insert into public.profiles(user_id, name) values(p_user, v_invite.name) on conflict(user_id) do nothing;
  insert into public.user_office_preferences(user_id, active_organization_id) values(p_user, v_invite.organization_id) on conflict(user_id) do nothing;
  update public.employee_invitations set accepted_at = now() where id = p_invitation;
end;
$$;
create function public.my_office_invitations() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', i.id, 'name', o.name, 'employee_code', i.employee_code)
  from public.employee_invitations i join public.organizations o on o.id = i.organization_id
  where i.user_id = (select auth.uid()) and i.accepted_at is null and exists(
    select 1 from public.memberships m where m.user_id = i.invited_by and m.organization_id = i.organization_id and m.active and m.role = 'admin');
$$;
create function public.accept_office_invitation(p_invitation uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_invite public.employee_invitations; v_existing public.memberships;
begin
  perform 1 from auth.users where id = auth.uid() for update;
  select * into v_invite from public.employee_invitations where id = p_invitation and user_id = auth.uid();
  if v_invite.id is null then raise exception 'forbidden'; end if;
  perform 1 from public.organizations where id = v_invite.organization_id for share;
  select * into v_invite from public.employee_invitations where id = p_invitation and user_id = auth.uid() for update;
  if v_invite.id is null then raise exception 'forbidden'; end if;
  perform 1 from public.memberships where organization_id = v_invite.organization_id and user_id = v_invite.invited_by and active and role = 'admin' for share;
  if not found then raise exception 'forbidden'; end if;
  select * into v_existing from public.memberships where organization_id = v_invite.organization_id and user_id = auth.uid() for update;
  if v_existing.id is not null then
    if not v_existing.active or v_existing.employee_code <> v_invite.employee_code then raise exception 'inactive'; end if;
  else
    if v_invite.accepted_at is not null then raise exception 'inactive'; end if;
    insert into public.memberships(user_id, organization_id, employee_code, department)
      values(auth.uid(), v_invite.organization_id, v_invite.employee_code, v_invite.department);
  end if;
  insert into public.profiles(user_id, name) values(auth.uid(), v_invite.name) on conflict(user_id) do nothing;
  update public.employee_invitations set accepted_at = coalesce(accepted_at, now()) where id = p_invitation;
  return v_invite.organization_id;
end;
$$;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
  values('office-logos', 'office-logos', false, 2097152, array['image/jpeg','image/png']);
-- Compare text rather than casting untrusted object names to UUID.
create policy office_logo_read on storage.objects for select to authenticated using (
  bucket_id = 'office-logos' and exists(select 1 from public.memberships m
    where m.organization_id::text = (storage.foldername(name))[1] and m.user_id = (select auth.uid()) and m.active)
);
create policy office_logo_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'office-logos' and exists(select 1 from public.memberships m
    where m.organization_id::text = (storage.foldername(name))[1] and m.user_id = (select auth.uid()) and m.active and m.role = 'admin')
);
create or replace function public.orphaned_media() returns table(bucket_id text, name text)
language sql stable security definer set search_path = '' as $$
  select o.bucket_id, o.name from storage.objects o where o.created_at < now() - interval '1 day' and (
    (o.bucket_id = 'attendance-evidence' and not exists(select 1 from public.attendance_evidence e where e.photo_path = o.name)) or
    (o.bucket_id = 'profile-media' and not exists(select 1 from public.profiles p where p.avatar_path = o.name or p.banner_path = o.name)) or
    (o.bucket_id = 'office-logos' and not exists(select 1 from public.organizations g where g.logo_path = o.name))
  ) order by o.created_at limit 500;
$$;

-- New functions default to PUBLIC execute unless explicitly revoked.
revoke all on function public.single_office_for(uuid), public.active_office_id(), public.current_employee(uuid), public.resolve_office_context(), public.switch_office(uuid), public.my_offices(), public.create_office(text), public.update_office(uuid,text,text), public.company_employees(uuid), public.save_attendance_policy(uuid,text,integer,integer), public.set_employee_active(uuid,uuid,text,boolean), public.claim_submission(uuid,uuid,uuid), public.finalize_check_in(uuid,uuid,uuid,timestamptz,text,text,double precision,double precision,double precision,uuid,text), public.invitation_user(text), public.my_office_invitations(), public.accept_office_invitation(uuid) from public, anon, authenticated;
grant execute on function public.active_office_id(), public.current_employee(uuid), public.resolve_office_context(), public.switch_office(uuid), public.my_offices(), public.create_office(text), public.update_office(uuid,text,text), public.company_employees(uuid), public.save_attendance_policy(uuid,text,integer,integer), public.my_office_invitations(), public.accept_office_invitation(uuid) to authenticated;
grant execute on function public.single_office_for(uuid), public.set_employee_active(uuid,uuid,text,boolean), public.claim_submission(uuid,uuid,uuid), public.finalize_check_in(uuid,uuid,uuid,timestamptz,text,text,double precision,double precision,double precision,uuid,text), public.invitation_user(text) to service_role;
revoke all on function public.set_office_role(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.set_office_role(uuid,uuid,text) to authenticated;
commit;
