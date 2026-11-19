begin;

create index check_ins_office_recent
  on public.check_ins (organization_id, received_at desc, id desc);

create function public.office_check_in_activity(p_organization uuid)
returns table (id uuid, employee_name text, received_at timestamptz, office_timezone text)
language plpgsql stable security invoker set search_path = ''
as $$
begin
  if p_organization is null
    or p_organization is distinct from (select public.active_office_id())
    or not (select public.is_company_admin(p_organization)) then
    raise exception 'office_admin_required' using errcode = '42501';
  end if;

  return query
    select recent.id, coalesce(p.name, recent.employee_code), recent.received_at, o.timezone
    from (
      select c.id, c.user_id, c.employee_code, c.received_at
      from public.check_ins c
      where c.organization_id = p_organization
      order by c.received_at desc, c.id desc
      limit 30
    ) recent
    join public.organizations o on o.id = p_organization
    left join public.profiles p on p.user_id = recent.user_id
    order by recent.received_at desc, recent.id desc;
end;
$$;

revoke execute on function public.office_check_in_activity(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.office_check_in_activity(uuid) to authenticated;

commit;
