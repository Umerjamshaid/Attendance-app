import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.119.0';
import { ApiError } from './validation.ts';
export { ApiError } from './validation.ts';

const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
/** Creates an unpersisted server client; credentials never enter the public app. */
export function adminClient(): SupabaseClient {
  const key = Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!key) throw new Error('Missing server credential');
  return createClient(Deno.env.get('SUPABASE_URL')!, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
/** Validates the bearer token and active membership, optionally requiring an admin. */
export async function actor(req: Request, adminOnly = false) {
  const token = req.headers.get('authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) throw new ApiError(401, 'unauthorized');
  const db = adminClient();
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) throw new ApiError(401, 'unauthorized');
  const { data: membership } = await db.from('memberships').select('*').eq('user_id', data.user.id).eq('active', true).maybeSingle();
  if (!membership) throw new ApiError(403, 'inactive');
  if (adminOnly && membership.role !== 'admin') throw new ApiError(403, 'forbidden');
  return { db, user: data.user, membership };
}
/** Reads a bounded JSON object, rejecting oversized or malformed request bodies. */
async function body(req: Request): Promise<Record<string, unknown>> {
  const reader = req.body?.getReader();
  if (!reader) throw new ApiError(400, 'invalid_input');
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > 3_000_000) { await reader.cancel(); throw new ApiError(413, 'invalid_input'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try {
    const parsed = JSON.parse(new TextDecoder().decode(bytes));
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) return parsed;
  } catch { /* Return a stable public error instead of a parser trace. */ }
  throw new ApiError(400, 'invalid_input');
}
/** Applies CORS, bounded parsing and public error codes without leaking request data. */
export function handle(action: (req: Request, input: Record<string, unknown>) => Promise<unknown>) {
  return async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers });
    if (req.method !== 'POST') return new Response(JSON.stringify({ code: 'method_not_allowed' }), { status: 405, headers });
    try { return new Response(JSON.stringify(await action(req, await body(req))), { headers }); }
    catch (error) {
      const known = error instanceof ApiError;
      const code = known ? error.code : 'server_error';
      console.error(JSON.stringify({ event: 'request_failed', code }));
      return new Response(JSON.stringify({ code }), { status: known ? error.status : 500, headers });
    }
  };
}
