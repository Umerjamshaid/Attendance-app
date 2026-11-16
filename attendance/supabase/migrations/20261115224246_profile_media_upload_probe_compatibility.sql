begin;

-- The pre-upload probe may report the multipart request's Content-Length,
-- including boundaries. Validate final Storage metadata, which includes size.
drop trigger profile_media_size_guard on storage.objects;
create trigger profile_media_size_guard
before insert or update of bucket_id, name, metadata on storage.objects
for each row
when (new.bucket_id = 'profile-media' and new.metadata ? 'size')
execute function public.enforce_profile_media_size();

commit;
