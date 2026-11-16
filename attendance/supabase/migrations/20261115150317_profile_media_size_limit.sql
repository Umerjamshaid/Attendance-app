-- Match the profile client limit; preserve evidence, MIME and privacy rules.
update storage.buckets
set file_size_limit = 5242880
where id = 'profile-media';
