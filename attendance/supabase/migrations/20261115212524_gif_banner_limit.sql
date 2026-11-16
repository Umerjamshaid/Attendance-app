-- This shared bucket needs a 10 MiB ceiling for GIF banners. The client keeps
-- avatars and non-GIF banners at 5 MiB; evidence and logos have separate buckets.
update storage.buckets
set file_size_limit = 10485760
where id = 'profile-media';
