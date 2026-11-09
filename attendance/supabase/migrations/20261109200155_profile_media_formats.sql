-- Preserve private access, size limits, and attendance evidence restrictions.
update storage.buckets
set allowed_mime_types = array[
  'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'
]
where id = 'profile-media';
