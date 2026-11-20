// account: the signed-in user's own account.
//
//   POST { action: "set_password", new_password }   Authorization: the user
//        200 { ok }  Only while the account is on a temporary PIN (first
//        sign-in or after an admin reset). Clears the flag; the app then
//        refreshes its session to pick up the new claim.
//
// Changing a password later is done in the app with the current password
// (Supabase Auth updateUser), so it does not need this function.
import type { Backend } from '../_shared/backend.ts';
import { callerProfile } from '../_shared/caller.ts';
import { readBody, reply } from '../_shared/http.ts';
import { passwordProblem } from '../_shared/rules.ts';

export async function handler(req: Request, b: Backend): Promise<Response> {
  const body = await readBody(req);
  if (body instanceof Response) return body;
  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;

  if (body.action !== 'set_password') return reply(400, { error: 'unknown_action' });
  if (caller.appMetadata.must_change_password !== true) {
    return reply(403, { error: 'not_required' });
  }
  const password = typeof body.new_password === 'string' ? body.new_password : '';
  const problem = passwordProblem(password, caller.profile.user_code);
  if (problem) return reply(400, { error: 'validation_failed', fields: { new_password: problem } });
  if (/^[0-9]{6}$/.test(password)) {
    return reply(400, {
      error: 'validation_failed',
      fields: { new_password: 'Choose a new password, not a PIN' },
    });
  }

  await b.setPassword(caller.profile.id, password);
  await b.mergeAppMetadata(caller.profile.id, { must_change_password: false });
  return reply(200, { ok: true });
}
