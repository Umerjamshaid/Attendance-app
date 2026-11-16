begin;

-- Storage's authorization probe may have no size yet. Final writes include
-- measured metadata, including when the Storage service bypasses caller RLS.
-- Keep this narrow custom trigger covered when upgrading the Storage service.
create function public.enforce_profile_media_size() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_bytes numeric := 0;
  v_field text;
  v_limit integer := 5242880;
begin
  if new.bucket_id <> 'profile-media' then return new; end if;
  if new.metadata is null then return new; end if;
  foreach v_field in array array['size', 'contentLength'] loop
    if new.metadata ? v_field then
      if coalesce(new.metadata->>v_field, '') !~ '^[0-9]+$' then
        raise exception 'invalid_profile_media_size' using errcode = '23514';
      end if;
      v_bytes := greatest(v_bytes, (new.metadata->>v_field)::numeric);
    end if;
  end loop;
  if new.name ~ '^[^/]+/banner-[^/]+[.]gif$'
     and lower(new.metadata->>'mimetype') = 'image/gif' then
    v_limit := 10485760;
  end if;
  if v_bytes > v_limit then
    raise exception 'profile_media_too_large' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_profile_media_size() from public, anon, authenticated;
create trigger profile_media_size_guard
before insert or update of bucket_id, name, metadata on storage.objects
for each row execute function public.enforce_profile_media_size();

commit;
