import { actor, handle, ApiError } from '../_shared/server.ts';
import { uuid } from '../_shared/validation.ts';

Deno.serve(handle(async (req, input) => {
  const { db, membership } = await actor(req, true);
  const { data, error } = await db.from('attendance_evidence').select('*').eq('check_in_id', uuid(input.record_id)).eq('organization_id', membership.organization_id).gt('expires_at', new Date().toISOString()).maybeSingle();
  if (error) throw error;
  if (!data) throw new ApiError(404, 'evidence_expired');
  const { data: signed, error: signError } = await db.storage.from('attendance-evidence').createSignedUrl(data.photo_path, 60);
  if (signError) throw signError;
  return { photo_url: signed.signedUrl, latitude: data.latitude, longitude: data.longitude, accuracy: data.accuracy };
}));
