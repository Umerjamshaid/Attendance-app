import { actor, handle, ApiError } from '../_shared/server.ts';
import { coordinate, image, text, uuid } from '../_shared/validation.ts';

Deno.serve(handle(async (req, input) => {
  const { db, user, membership } = await actor(req);
  const requestId = uuid(input.request_id);
  const existing = await db.from('check_ins').select('*').eq('user_id', user.id).eq('request_id', requestId).maybeSingle();
  if (existing.error) throw existing.error;
  if (existing.data) return { record: existing.data };
  const latitude = coordinate(input.latitude, -90, 90);
  const longitude = coordinate(input.longitude, -180, 180);
  const accuracy = coordinate(input.accuracy, 0, 100);
  const captured = text(input.captured_at, 40);
  if (!Number.isFinite(Date.parse(captured)) || Math.abs(Date.now() - Date.parse(captured)) > 15 * 60_000) throw new ApiError(400, 'invalid_input');
  const installation = uuid(input.installation_id);
  const device = text(input.device_model, 120);
  const platform = text(input.platform, 7, /^(android|ios)$/);
  const photo = image(input.image);
  const { data: claim, error: claimError } = await db.rpc('claim_submission', { p_user: user.id, p_request: requestId });
  if (claimError) throw claimError;
  if (!claim) throw new ApiError(409, 'processing');
  const path = `${membership.organization_id}/${user.id}/${requestId}`;
  // The same attempt never overwrites an existing object. Uncommitted objects
  // are cleaned later, not on ambiguous timeouts that may have committed.
  const { error: uploadError } = await db.storage.from('attendance-evidence').upload(path, photo.bytes, { contentType: photo.contentType, upsert: false });
  if (uploadError && !['409','Duplicate'].includes(String(uploadError.statusCode ?? uploadError.name))) throw uploadError;
  const { data: record, error } = await db.rpc('finalize_check_in', {
    p_user: user.id, p_request: requestId, p_captured: captured, p_device: device,
    p_photo: path, p_lat: latitude, p_lng: longitude, p_accuracy: accuracy,
    p_installation: installation, p_platform: platform,
  });
  if (error) {
    if (error.message.includes('window_closed')) throw new ApiError(403, 'window_closed');
    if (error.message.includes('inactive')) throw new ApiError(403, 'inactive');
    throw error;
  }
  return { record };
}));
