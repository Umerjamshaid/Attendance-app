import { adminClient, handle, ApiError } from '../_shared/server.ts';

/** Deletes expired evidence and orphaned media for an authenticated retention job. */
async function retentionCleanup(req: Request) {
  const secret = Deno.env.get('CRON_SECRET');
  if (!secret || req.headers.get('authorization') !== `Bearer ${secret}`) throw new ApiError(401, 'unauthorized');
  const db = adminClient();
  let removed = 0;
  while (true) {
    const { data, error } = await db.from('attendance_evidence').select('check_in_id,photo_path').lte('expires_at', new Date().toISOString()).limit(100);
    if (error) throw error;
    if (!data.length) break;
    const { error: storageError } = await db.storage.from('attendance-evidence').remove(data.map((row) => row.photo_path));
    if (storageError) throw storageError;
    const { error: deleteError } = await db.from('attendance_evidence').delete().in('check_in_id', data.map((row) => row.check_in_id));
    if (deleteError) throw deleteError;
    removed += data.length;
    if (removed >= 1000) break;
  }
  const { data: orphans, error: orphanError } = await db.rpc('orphaned_media');
  if (orphanError) throw orphanError;
  for (const bucket of ['attendance-evidence','profile-media']) {
    const paths = (orphans as { bucket_id: string; name: string }[]).filter((row) => row.bucket_id === bucket).map((row) => row.name);
    if (paths.length) { const { error } = await db.storage.from(bucket).remove(paths); if (error) throw error; }
  }
  const { error: attemptsError } = await db.from('submission_attempts').delete().lt('created_at', new Date(Date.now() - 86400_000).toISOString());
  if (attemptsError) throw attemptsError;
  return { ok: true, removed };
}

Deno.serve(handle(retentionCleanup));
