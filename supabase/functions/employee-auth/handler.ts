// employee-auth: the only way an employee gets a session, and the only place
// a PIN is set. Every rule that matters lives in the database (the lockout in
// public.employee_login_check, the PIN rule in private.pin_problem); this file
// turns the answers into HTTP replies and refuses everything unexpected.
//
//   POST { "action": "login", "employee_code": "DA-014", "pin": "482915" }
//        no Authorization needed (nobody is signed in yet)
//        200 { session, must_change_pin }
//        401 invalid_credentials | 403 account_blocked | 429 account_locked
//   POST { "action": "change_pin", "new_pin": "135792" }   Authorization: employee
//        200 { ok: true }   only while "must change PIN" is set (first login)
//        400 validation_failed | 401 | 403 pin_change_not_allowed
//   POST { "action": "reset_pin", "employee_id": "<uuid>", "new_pin": "..." }
//        Authorization: an active admin
//        200 { ok: true }   the employee must change it at the next sign-in
//
// Never logged: PINs, codes, names.

import type { Deps } from './deps.ts';
import { isUuid, type Json, reply } from './http.ts';

const MAX_CODE = 20;
const MAX_PIN = 12;

export async function handler(req: Request, d: Deps): Promise<Response> {
  if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' });

  let body: Json;
  try {
    body = (await req.json()) as Json;
  } catch {
    return reply(400, { error: 'validation_failed' });
  }
  if (typeof body !== 'object' || body === null) return reply(400, { error: 'validation_failed' });

  switch (body.action) {
    case 'login':
      return login(body, d);
    case 'change_pin':
      return changePin(req, body, d);
    case 'reset_pin':
      return resetPin(req, body, d);
    default:
      return reply(400, { error: 'unknown_action' });
  }
}

async function login(body: Json, d: Deps): Promise<Response> {
  const code = typeof body.employee_code === 'string' ? body.employee_code.trim() : '';
  const pin = typeof body.pin === 'string' ? body.pin : '';
  if (code === '' || code.length > MAX_CODE || pin === '' || pin.length > MAX_PIN) {
    return reply(400, { error: 'validation_failed' });
  }

  let check;
  try {
    check = await d.loginCheck(code, pin);
  } catch {
    return reply(500, { error: 'login_failed' });
  }

  switch (check.result) {
    case 'invalid':
      return reply(401, { error: 'invalid_credentials' });
    case 'blocked':
      return reply(403, { error: 'account_blocked' });
    case 'locked':
      return reply(429, {
        error: 'account_locked',
        retry_after_seconds: check.retry_after_seconds,
      });
    case 'ok': {
      let session;
      try {
        session = await d.signIn(check.email, check.login_password);
      } catch {
        return reply(500, { error: 'login_failed' });
      }
      if (!session) return reply(500, { error: 'login_failed' });
      return reply(200, { session, must_change_pin: check.must_change_pin });
    }
    default:
      return reply(500, { error: 'login_failed' });
  }
}

async function changePin(req: Request, body: Json, d: Deps): Promise<Response> {
  const auth = req.headers.get('Authorization');
  if (!auth) return reply(401, { error: 'unauthenticated' });
  const userId = await d.userId(auth);
  if (!userId) return reply(401, { error: 'unauthenticated' });

  const profile = await d.profileOf(userId);
  if (!profile || profile.role !== 'employee' || profile.status !== 'active') {
    return reply(403, { error: 'forbidden' });
  }
  // A PIN can only be changed here while the admin-given one is still in use.
  // Changing a PIN later needs the current PIN, which is not built yet.
  if (!profile.must_change_pin) return reply(403, { error: 'pin_change_not_allowed' });

  const pin = typeof body.new_pin === 'string' ? body.new_pin : '';
  if (pin === '' || pin.length > MAX_PIN) return reply(400, { error: 'validation_failed' });

  const result = await d.setPin(userId, pin, false);
  if (!result.ok) {
    return reply(400, { error: 'validation_failed', fields: { pin: result.problem } });
  }
  return reply(200, { ok: true });
}

async function resetPin(req: Request, body: Json, d: Deps): Promise<Response> {
  const auth = req.headers.get('Authorization');
  if (!auth) return reply(401, { error: 'unauthenticated' });
  const actorId = await d.userId(auth);
  if (!actorId) return reply(401, { error: 'unauthenticated' });
  if (!(await d.isAdmin(auth))) return reply(403, { error: 'forbidden' });

  const employeeId = body.employee_id;
  const pin = typeof body.new_pin === 'string' ? body.new_pin : '';
  if (!isUuid(employeeId) || pin === '' || pin.length > MAX_PIN) {
    return reply(400, { error: 'validation_failed' });
  }
  const target = await d.profileOf(employeeId);
  if (!target || target.role !== 'employee') return reply(404, { error: 'employee_not_found' });

  const result = await d.adminResetPin(actorId, employeeId, pin);
  if (!result.ok) {
    return reply(400, { error: 'validation_failed', fields: { pin: result.problem } });
  }
  return reply(200, { ok: true });
}
