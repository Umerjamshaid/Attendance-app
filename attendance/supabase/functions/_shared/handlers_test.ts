import assert from 'node:assert/strict';

type Handler = (request: Request) => Response | Promise<Response>;
const user = '20000000-0000-4000-8000-000000000001';
const company = '10000000-0000-4000-8000-000000000001';
const requestId = '30000000-0000-4000-8000-000000000001';

/** Imports the actual entrypoint without starting a listening HTTP server. */
async function capture(path: string): Promise<Handler> {
  const serve = Deno.serve;
  let handler: Handler | undefined;
  Deno.serve = ((action: Handler) => { handler = action; return {}; }) as unknown as typeof Deno.serve;
  try { await import(path); } finally { Deno.serve = serve; }
  assert.ok(handler);
  return handler;
}

const manage = await capture('../manage-employees/index.ts');
const submit = await capture('../submit-attendance/index.ts');

interface Scenario {
  duplicateCode?: boolean;
  lookupFailure?: boolean;
  invitation?: { id: string; employee_code: string; user_id: string };
  uploadStatus?: number;
  uploadDisconnect?: boolean;
  finalizeCode?: string;
  finalizeDisconnect?: boolean;
  claim?: boolean;
  registeredUser?: boolean;
  multipleMemberships?: boolean;
  wrongOffice?: boolean;
}

/** Exercises a real handler against isolated Auth, Data and Storage HTTP responses. */
async function run(handler: Handler, scenario: Scenario, input: Record<string, unknown>) {
  const fetch = globalThis.fetch;
  const keys = ['SUPABASE_URL', 'SUPABASE_SECRET_KEY'];
  const previous = keys.map((key) => Deno.env.get(key));
  Deno.env.set(keys[0], 'https://backend.example.invalid');
  Deno.env.set(keys[1], 'test-only-key');
  const calls: { url: URL; method: string }[] = [];
  globalThis.fetch = async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    assert.equal(url.origin, 'https://backend.example.invalid');
    const method = init?.method ?? (input instanceof Request ? input.method : 'GET');
    calls.push({ url, method });
    let data: unknown;
    let status = 200;
    switch (url.pathname) {
      case '/auth/v1/user':
      case '/auth/v1/invite':
        data = { id: user, aud: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() };
        break;
      case '/rest/v1/memberships':
        if (url.searchParams.has('employee_code')) {
          if (scenario.lookupFailure) { status = 500; data = { code: 'XX000', message: 'Test lookup failure' }; }
          else data = scenario.duplicateCode ? [{ user_id: user }] : [];
        } else {
          data = scenario.wrongOffice ? [] : [{ user_id: user, organization_id: company, role: 'admin', active: true }];
          if (scenario.multipleMemberships && !url.searchParams.has('organization_id')) {
            data = [...data as object[], { user_id: user, organization_id: '10000000-0000-4000-8000-000000000002', role: 'employee', active: true }];
          }
        }
        break;
      case '/rest/v1/employee_invitations':
        data = method === 'GET' ? (scenario.invitation ? [scenario.invitation] : []) : { id: 'invitation', user_id: null };
        if (method === 'PATCH') { status = 204; data = null; }
        break;
      case '/rest/v1/check_ins': data = []; break;
      case '/rest/v1/rpc/claim_submission': data = scenario.claim ?? true; break;
      case '/rest/v1/rpc/finalize_check_in':
        if (scenario.finalizeDisconnect) throw new TypeError('Test lost connection');
        if (scenario.finalizeCode) {
          status = scenario.finalizeCode === 'PGRST003' ? 504 : 400;
          data = { code: scenario.finalizeCode, message: scenario.finalizeCode === 'P0001' ? 'window_closed' : 'Test failure' };
        } else data = { id: 'saved' };
        break;
      case '/rest/v1/rpc/complete_employee_invitation': data = null; break;
      case '/rest/v1/rpc/invitation_user': data = scenario.registeredUser ? user : null; break;
      case '/rest/v1/submission_attempts': status = 204; data = null; break;
      default:
        assert.ok(url.pathname.startsWith('/storage/v1/object/attendance-evidence/'));
        if (scenario.uploadDisconnect) throw new TypeError('Test lost connection');
        status = scenario.uploadStatus ?? 200;
        data = status === 200 ? { Key: 'photo', Id: 'photo' } : { code: status === 409 ? 'ResourceAlreadyExists' : 'InvalidRequest', message: 'Test upload rejection' };
    }
    return new Response(status === 204 ? null : JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
  };
  try {
    const response = await handler(new Request('https://function.example.invalid', {
      method: 'POST', headers: { Authorization: 'Bearer test-token' }, body: JSON.stringify(input),
    }));
    return { response, data: await response.json(), calls };
  } finally {
    globalThis.fetch = fetch;
    keys.forEach((key, index) => previous[index] === undefined ? Deno.env.delete(key) : Deno.env.set(key, previous[index]!));
  }
}

const invite = { action: 'invite', employee_code: 'EMP001', email: 'employee@example.invalid', name: 'Employee', department: 'Engineering' };

Deno.test('duplicate employee code is rejected before insertion or email delivery', async () => {
  const result = await run(manage, { duplicateCode: true }, invite);
  assert.equal(result.response.status, 409);
  assert.equal(result.data.code, 'duplicate_employee');
  assert.ok(!result.calls.some(({ method }) => method === 'POST'));
  const lookup = result.calls.find(({ url }) => url.pathname.endsWith('/memberships') && url.searchParams.has('employee_code'))!;
  assert.equal(lookup.url.searchParams.get('organization_id'), `eq.${company}`);
  assert.equal(lookup.url.searchParams.get('employee_code'), 'eq.EMP001');
});

Deno.test('membership lookup failure does not send an invitation', async () => {
  const result = await run(manage, { lookupFailure: true }, invite);
  assert.equal(result.response.status, 500);
  assert.ok(!result.calls.some(({ method }) => method === 'POST'));
});

Deno.test('existing invitation retries bypass the new-member precheck', async () => {
  const result = await run(manage, { duplicateCode: true, invitation: { id: 'existing', employee_code: 'EMP001', user_id: user } }, invite);
  assert.equal(result.response.status, 200);
  assert.ok(!result.calls.some(({ url }) => url.searchParams.has('employee_code') || url.pathname.endsWith('/invite')));
  assert.ok(result.calls.some(({ url }) => url.pathname.endsWith('/complete_employee_invitation')));
});

for (const [name, scenario, released] of [
  ['explicit upload rejection', { uploadStatus: 400 }, true],
  ['upload timeout', { uploadStatus: 408 }, false],
  ['upload server failure', { uploadStatus: 503 }, false],
  ['upload disconnect', { uploadDisconnect: true }, false],
  ['window rejection', { finalizeCode: 'P0001' }, true],
  ['constraint rejection', { finalizeCode: '23514' }, true],
  ['database timeout', { finalizeCode: 'PGRST003' }, false],
  ['finalization disconnect', { finalizeDisconnect: true }, false],
  ['another request owns the lease', { claim: false }, false],
  ['existing photo can be finalized', { uploadStatus: 409 }, false],
] as const) {
  Deno.test(`submission lease handling: ${name}`, async () => {
    const result = await run(submit, scenario, {
      request_id: requestId, latitude: 24, longitude: 67, accuracy: 5,
      captured_at: new Date().toISOString(), installation_id: '40000000-0000-4000-8000-000000000001',
      device_model: 'Test phone', platform: 'android',
      image: btoa(String.fromCharCode(137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0)),
    });
    const deletions = result.calls.filter(({ url, method }) => url.pathname.endsWith('/submission_attempts') && method === 'DELETE');
    assert.equal(deletions.length, released ? 1 : 0);
    for (const { url } of deletions) {
      assert.equal(url.searchParams.get('organization_id'), `eq.${company}`);
      assert.equal(url.searchParams.get('user_id'), `eq.${user}`);
      assert.equal(url.searchParams.get('request_id'), `eq.${requestId}`);
    }
    assert.equal(result.response.status === 200, scenario.uploadStatus === 409);
  });
}

Deno.test('multi-office clients must provide an authorized office', async () => {
  const ambiguous = await run(manage, { multipleMemberships: true }, invite);
  assert.equal(ambiguous.response.status, 409);
  assert.equal(ambiguous.data.code, 'office_required');
  const denied = await run(manage, { wrongOffice: true }, { ...invite, organization_id: company });
  assert.equal(denied.response.status, 403);
  assert.ok(!denied.calls.some(({ method }) => method === 'POST'));
});

Deno.test('registered invitees do not receive a failing Auth duplicate invitation', async () => {
  const result = await run(manage, { registeredUser: true }, { ...invite, organization_id: company });
  assert.equal(result.response.status, 200);
  assert.ok(result.calls.some(({ url }) => url.pathname.endsWith('/complete_employee_invitation')));
  assert.ok(!result.calls.some(({ url }) => url.pathname.endsWith('/invite')));
});
