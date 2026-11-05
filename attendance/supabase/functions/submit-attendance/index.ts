import { actor, handle, ApiError } from '../_shared/server.ts';
import { coordinate, image, text, uuid } from '../_shared/validation.ts';
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.119.0';

/** Distinguishes explicit rejections/rollbacks from possibly committed timeouts. */
function confirmedFailure(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const code = 'code' in error ? String(error.code) : '';
  if (/^(22|23|25|28|40|42|P0)[A-Z0-9]{3}$/.test(code)) return true;
  const status = 'status' in error ? Number(error.status) : 'statusCode' in error ? Number(error.statusCode) : 0;
  return status >= 400 && status < 500 && status !== 408;
}

/** Releases only this request's lease after a confirmed failure, preserving its error. */
async function releaseFailedAttempt(db: SupabaseClient, userId: string, requestId: string, error: unknown) {
  if (!confirmedFailure(error)) return;
  try {
    const { error: releaseError } = await db.from('submission_attempts').delete().eq('user_id', userId).eq('request_id', requestId);
    if (releaseError) throw releaseError;
  } catch {
    console.error(JSON.stringify({ event: 'submission_release_failed', code: 'server_error' }));
  }
}

/** Stores one authenticated photo check-in, retaining leases for ambiguous failures. */
async function submitAttendance(req: Request, input: Record<string, unknown>) {
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
  try {
    const { error: uploadError } = await db.storage.from('attendance-evidence').upload(path, photo.bytes, { contentType: photo.contentType, upsert: false });
    if (uploadError && uploadError.status !== 409 && !['409','Duplicate','ResourceAlreadyExists','KeyAlreadyExists'].includes(String(uploadError.statusCode ?? uploadError.name))) throw uploadError;
    const { data: record, error } = await db.rpc('finalize_check_in', {
      p_user: user.id, p_request: requestId, p_captured: captured, p_device: device,
      p_photo: path, p_lat: latitude, p_lng: longitude, p_accuracy: accuracy,
      p_installation: installation, p_platform: platform,
    });
    if (error) throw error;
    return { record };
  } catch (error) {
    await releaseFailedAttempt(db, user.id, requestId, error);
    if (error && typeof error === 'object' && 'code' in error && error.code === 'P0001' && 'message' in error) {
      if (String(error.message).includes('window_closed')) throw new ApiError(403, 'window_closed');
      if (String(error.message).includes('inactive')) throw new ApiError(403, 'inactive');
    }
    throw error;
  }
}

Deno.serve(handle(submitAttendance));
