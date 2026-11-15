-- Only a member's currently selected avatar is shared with their office admins.
-- Existing own-media access, banners, uploads and attendance evidence are unchanged.
create policy office_admin_avatar_read on storage.objects
for select to authenticated using (
  bucket_id = 'profile-media'
  and (select public.is_company_admin(public.active_office_id()))
  and exists (
    select 1
    from public.profiles p
    join public.memberships m on m.user_id = p.user_id
    where p.avatar_path = storage.objects.name
      and m.organization_id = (select public.active_office_id())
  )
);
