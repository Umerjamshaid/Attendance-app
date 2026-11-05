-- Company pilot: public app data only; no private attendance integration.
begin;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 100),
  timezone text not null default 'Asia/Karachi',
  window_mode text not null default 'period' check (window_mode in ('always','period')),
  start_hour integer not null default 7 check (start_hour between 0 and 23),
  end_hour integer not null default 13 check (end_hour between 1 and 24),
  check (end_hour > start_hour),
  created_at timestamptz not null default now()
);

create table public.memberships (
  user_id uuid primary key references auth.users(id) on delete restrict,
  organization_id uuid not null references public.organizations(id),
  employee_code text not null check (employee_code ~ '^[A-Z0-9_-]{1,32}$'),
  role text not null default 'employee' check (role in ('admin','employee')),
  department text not null default '' check (length(department) <= 100),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, employee_code),
  unique (organization_id, user_id)
);
create index memberships_org_active on public.memberships(organization_id, active);

create table public.profiles (
  user_id uuid primary key references public.memberships(user_id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 100),
  headline text not null default '' check (length(headline) <= 160),
  chips text[] not null default '{}' check (cardinality(chips) <= 12 and length(chips::text) <= 650),
  avatar_path text,
  banner_path text,
  check (avatar_path is null or avatar_path like user_id::text || '/avatar-%'),
  check (banner_path is null or banner_path like user_id::text || '/banner-%')
);

create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  user_id uuid not null,
  employee_code text not null,
  request_id uuid not null,
  received_at timestamptz not null default now(),
  captured_at timestamptz not null,
  company_day date not null,
  device_model text not null check (length(device_model) between 1 and 120),
  foreign key (organization_id, user_id) references public.memberships(organization_id, user_id),
  unique (organization_id, user_id, request_id)
);
create index check_ins_owner_time on public.check_ins(user_id, received_at desc, id);
create index check_ins_company_day on public.check_ins(organization_id, company_day, received_at desc);

-- Evidence is separate: an employee's SELECT on check_ins cannot expose GPS.
create table public.attendance_evidence (
  check_in_id uuid primary key references public.check_ins(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  photo_path text not null unique,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy double precision not null check (accuracy between 0 and 100),
  installation_id uuid not null,
  platform text not null check (platform in ('android','ios')),
  expires_at timestamptz not null default (now() + interval '90 days')
);
create index evidence_expiry on public.attendance_evidence(expires_at);

create table public.submission_attempts (
  user_id uuid not null references public.memberships(user_id),
  request_id uuid not null,
  lease_until timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (user_id, request_id)
);

create table public.employee_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  email text not null,
  employee_code text not null,
  name text not null,
  department text not null,
  user_id uuid,
  created_at timestamptz not null default now(),
  unique (organization_id, email),
  unique (organization_id, employee_code)
);

alter table public.organizations enable row level security;
alter table public.memberships enable row level security;
alter table public.profiles enable row level security;
alter table public.check_ins enable row level security;
alter table public.attendance_evidence enable row level security;
alter table public.submission_attempts enable row level security;
alter table public.employee_invitations enable row level security;

create function public.is_company_member(p_org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.memberships where user_id = (select auth.uid()) and organization_id = p_org and active);
$$;
create function public.is_company_admin(p_org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.memberships where user_id = (select auth.uid()) and organization_id = p_org and active and role = 'admin');
$$;

create policy organization_read on public.organizations for select to authenticated using (public.is_company_member(id));
create policy member_read on public.memberships for select to authenticated using (public.is_company_member(organization_id) and (user_id = (select auth.uid()) or public.is_company_admin(organization_id)));
create policy profile_read on public.profiles for select to authenticated using (exists(select 1 from public.memberships m where m.user_id = profiles.user_id));
create policy profile_update on public.profiles for update to authenticated
  using (user_id = (select auth.uid()) and exists(select 1 from public.memberships m where m.user_id = profiles.user_id and m.active))
  with check (user_id = (select auth.uid()) and exists(select 1 from public.memberships m where m.user_id = profiles.user_id and m.active));
create policy check_ins_read on public.check_ins for select to authenticated using (public.is_company_member(organization_id) and (user_id = (select auth.uid()) or public.is_company_admin(organization_id)));
create policy evidence_admin_read on public.attendance_evidence for select to authenticated using (public.is_company_admin(organization_id) and expires_at > now());

-- No direct client writes to attendance, membership, invitations, or evidence.
revoke all on public.organizations, public.memberships, public.profiles, public.check_ins, public.attendance_evidence, public.submission_attempts, public.employee_invitations from anon, authenticated;
grant select on public.organizations, public.memberships, public.profiles, public.check_ins, public.attendance_evidence to authenticated;
grant update (name, headline, chips, avatar_path, banner_path) on public.profiles to authenticated;
grant all on public.organizations, public.memberships, public.profiles, public.check_ins, public.attendance_evidence, public.submission_attempts, public.employee_invitations to service_role;

create function public.current_employee() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.employee_code, 'name', p.name, 'email', u.email, 'role', m.role, 'department', m.department, 'headline', p.headline, 'chips', p.chips, 'isActive', m.active, 'time', '')
  from public.memberships m join public.profiles p using (user_id) join auth.users u on u.id = m.user_id
  where m.user_id = (select auth.uid()) and m.active;
$$;
create function public.company_employees() returns setof jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.employee_code, 'name', p.name, 'email', u.email, 'role', m.role, 'department', m.department, 'headline', p.headline, 'chips', p.chips, 'isActive', m.active, 'time', '')
  from public.memberships m join public.profiles p using (user_id) join auth.users u on u.id = m.user_id
  where public.is_company_admin(m.organization_id) order by p.name;
$$;
create function public.save_attendance_policy(p_mode text, p_start integer, p_end integer) returns void
language plpgsql security definer set search_path = '' as $$
declare v_org uuid;
begin
  select organization_id into v_org from public.memberships where user_id = (select auth.uid()) and active and role = 'admin';
  if v_org is null then raise exception 'forbidden'; end if;
  update public.organizations set window_mode = p_mode, start_hour = p_start, end_hour = p_end where id = v_org;
end;
$$;

-- Lock the organization to serialize simultaneous changes to its last admin.
create function public.set_employee_active(p_actor uuid, p_code text, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare v_org uuid; v_target public.memberships;
begin
  select organization_id into v_org from public.memberships where user_id = p_actor and role = 'admin' and active;
  if v_org is null then raise exception 'forbidden'; end if;
  perform 1 from public.organizations where id = v_org for update;
  select * into v_target from public.memberships where organization_id = v_org and employee_code = p_code for update;
  if v_target.user_id is null then raise exception 'forbidden'; end if;
  if not p_active and v_target.role = 'admin' and v_target.active and
    (select count(*) from public.memberships where organization_id = v_org and role = 'admin' and active) <= 1 then raise exception 'last_admin'; end if;
  update public.memberships set active = p_active where user_id = v_target.user_id;
end;
$$;

create function public.claim_submission(p_user uuid, p_request uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  insert into public.submission_attempts(user_id, request_id, lease_until) values (p_user, p_request, now() + interval '90 seconds')
  on conflict (user_id, request_id) do update set lease_until = excluded.lease_until
    where public.submission_attempts.lease_until < now();
  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$$;

create function public.finalize_check_in(p_user uuid, p_request uuid, p_captured timestamptz, p_device text, p_photo text, p_lat double precision, p_lng double precision, p_accuracy double precision, p_installation uuid, p_platform text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_member public.memberships; v_org public.organizations; v_record public.check_ins; v_local timestamp;
begin
  select * into v_member from public.memberships where user_id = p_user and active for share;
  if v_member.user_id is null then raise exception 'inactive'; end if;
  select * into v_org from public.organizations where id = v_member.organization_id for share;
  select * into v_record from public.check_ins where organization_id = v_org.id and user_id = p_user and request_id = p_request;
  if v_record.id is not null then return to_jsonb(v_record); end if;
  v_local := now() at time zone v_org.timezone;
  if v_org.window_mode = 'period' and (extract(hour from v_local) < v_org.start_hour or extract(hour from v_local) >= v_org.end_hour) then raise exception 'window_closed'; end if;
  if p_photo <> v_org.id::text || '/' || p_user::text || '/' || p_request::text then raise exception 'forbidden'; end if;
  if not exists(select 1 from storage.objects where bucket_id = 'attendance-evidence' and name = p_photo) then raise exception 'missing_photo'; end if;
  insert into public.check_ins(organization_id, user_id, employee_code, request_id, captured_at, company_day, device_model)
  values (v_org.id, p_user, v_member.employee_code, p_request, p_captured, v_local::date, p_device)
  on conflict (organization_id, user_id, request_id) do nothing returning * into v_record;
  if v_record.id is null then
    select * into v_record from public.check_ins where organization_id = v_org.id and user_id = p_user and request_id = p_request;
    return to_jsonb(v_record);
  end if;
  insert into public.attendance_evidence(check_in_id, organization_id, photo_path, latitude, longitude, accuracy, installation_id, platform)
    values (v_record.id, v_org.id, p_photo, p_lat, p_lng, p_accuracy, p_installation, p_platform);
  delete from public.submission_attempts where user_id = p_user and request_id = p_request;
  return to_jsonb(v_record);
end;
$$;

-- Functions are not public by default: explicitly expose only safe entrypoints.
revoke all on function public.is_company_member(uuid), public.is_company_admin(uuid), public.current_employee(), public.company_employees(), public.save_attendance_policy(text, integer, integer), public.set_employee_active(uuid, text, boolean), public.claim_submission(uuid, uuid), public.finalize_check_in(uuid, uuid, timestamptz, text, text, double precision, double precision, double precision, uuid, text) from public, anon, authenticated;
grant execute on function public.is_company_member(uuid), public.is_company_admin(uuid), public.current_employee(), public.company_employees(), public.save_attendance_policy(text, integer, integer) to authenticated;
grant execute on function public.set_employee_active(uuid, text, boolean), public.claim_submission(uuid, uuid), public.finalize_check_in(uuid, uuid, timestamptz, text, text, double precision, double precision, double precision, uuid, text) to service_role;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types) values
  ('attendance-evidence', 'attendance-evidence', false, 2097152, array['image/jpeg','image/png']),
  ('profile-media', 'profile-media', false, 2097152, array['image/jpeg','image/png']);

-- Attendance evidence has no client INSERT/SELECT policy, including for employees.
-- Admin reads are brokered by attendance-evidence after an active-role check.
create policy own_profile_media_read on storage.objects for select to authenticated using (
  bucket_id = 'profile-media' and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists(select 1 from public.memberships where user_id = (select auth.uid()) and active)
);
create policy own_profile_media_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'profile-media' and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists(select 1 from public.memberships where user_id = (select auth.uid()) and active)
);
create policy own_profile_media_delete on storage.objects for delete to authenticated using (
  bucket_id = 'profile-media' and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists(select 1 from public.memberships where user_id = (select auth.uid()) and active)
);

create function public.complete_employee_invitation(p_actor uuid, p_invitation uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_invite public.employee_invitations; v_existing public.memberships;
begin
  select * into v_invite from public.employee_invitations where id = p_invitation for update;
  if not exists(select 1 from public.memberships where user_id = p_actor and organization_id = v_invite.organization_id and role = 'admin' and active) then raise exception 'forbidden'; end if;
  if v_invite.user_id is distinct from p_user then raise exception 'forbidden'; end if;
  select * into v_existing from public.memberships where user_id = p_user;
  if v_existing.user_id is not null and (v_existing.organization_id <> v_invite.organization_id or v_existing.employee_code <> v_invite.employee_code) then raise exception 'duplicate_employee'; end if;
  insert into public.memberships(user_id, organization_id, employee_code, department)
    values (p_user, v_invite.organization_id, v_invite.employee_code, v_invite.department) on conflict (user_id) do nothing;
  insert into public.profiles(user_id, name) values (p_user, v_invite.name) on conflict (user_id) do nothing;
end;
$$;
create function public.orphaned_media() returns table(bucket_id text, name text)
language sql stable security definer set search_path = '' as $$
  select o.bucket_id, o.name from storage.objects o
  where o.created_at < now() - interval '1 day' and (
    (o.bucket_id = 'attendance-evidence' and not exists(select 1 from public.attendance_evidence e where e.photo_path = o.name)) or
    (o.bucket_id = 'profile-media' and not exists(select 1 from public.profiles p where p.avatar_path = o.name or p.banner_path = o.name))
  ) order by o.created_at limit 500;
$$;
revoke all on function public.complete_employee_invitation(uuid, uuid, uuid), public.orphaned_media() from public, anon, authenticated;
grant execute on function public.complete_employee_invitation(uuid, uuid, uuid), public.orphaned_media() to service_role;

commit;
