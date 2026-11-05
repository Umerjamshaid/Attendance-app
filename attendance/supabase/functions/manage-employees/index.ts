import { actor, handle, ApiError } from '../_shared/server.ts';
import { text } from '../_shared/validation.ts';

Deno.serve(handle(async (req, input) => {
  const { db, user, membership } = await actor(req, true);
  const code = text(input.employee_code, 32, /^[A-Z0-9_-]{1,32}$/);
  if (input.action === 'set_active') {
    if (typeof input.active !== 'boolean') throw new ApiError(400, 'invalid_input');
    const { error } = await db.rpc('set_employee_active', { p_actor: user.id, p_code: code, p_active: input.active });
    if (error) throw new ApiError(403, error.message.includes('last_admin') ? 'last_admin' : 'forbidden');
    return { ok: true };
  }
  if (input.action !== 'invite') throw new ApiError(400, 'invalid_input');
  const email = text(input.email, 100, /^[^@\s]+@[^@\s]+\.[^@\s]+$/).toLowerCase();
  const name = text(input.name, 100);
  const department = text(input.department, 100);
  const { data: existing } = await db.from('employee_invitations').select('*').eq('organization_id', membership.organization_id).eq('email', email).maybeSingle();
  let invitation = existing;
  if (invitation && invitation.employee_code !== code) throw new ApiError(409, 'duplicate_employee');
  if (!invitation) {
    const { data, error } = await db.from('employee_invitations').insert({ organization_id: membership.organization_id, email, name, employee_code: code, department }).select().single();
    if (error) throw new ApiError(409, 'duplicate_employee');
    invitation = data;
  }
  let userId = invitation.user_id as string | null;
  if (!userId) {
    const { data, error } = await db.auth.admin.inviteUserByEmail(email, { redirectTo: 'workcheck://auth/callback', data: { password_set: false } });
    if (error || !data.user) throw new ApiError(400, ['email_exists','user_already_exists'].includes(error?.code ?? '') ? 'duplicate_employee' : 'invitation_delivery_failed');
    userId = data.user.id;
    const { error: saveError } = await db.from('employee_invitations').update({ user_id: userId }).eq('id', invitation.id);
    if (saveError) throw saveError;
  }
  const { error } = await db.rpc('complete_employee_invitation', { p_actor: user.id, p_invitation: invitation.id, p_user: userId });
  if (error) throw error;
  return { ok: true };
}));
