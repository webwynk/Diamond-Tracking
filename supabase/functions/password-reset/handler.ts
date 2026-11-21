// password-reset: forgotten password, by a code sent to the contact email.
//
//   POST { action: "request", user_code }   no sign-in needed
//        200 { ok }  Always the same answer, so it does not reveal whether a
//        user ID exists or has an email. 503 email_not_configured when the
//        project has no email service (users then ask the admin).
//        429 daily_email_limit when today's reset emails are used up.
//   POST { action: "confirm", user_code, code, new_password }
//        200 { ok }  400 invalid_code | validation_failed
//
// Codes: 6 digits, stored hashed, 15 minutes, 5 tries, one email a minute,
// 5 a day per user (more send nothing) and 90 a day in total.
// A successful reset signs the user out of every phone.
import type { Backend } from '../_shared/backend.ts';
import { type Json, readBody, reply, str } from '../_shared/http.ts';
import type { Mailer } from '../_shared/mailer.ts';
import { passwordProblem } from '../_shared/rules.ts';

export type CodeGenerator = () => string;

export function randomCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, '0');
}

export async function handler(
  req: Request,
  b: Backend,
  mail: Mailer,
  newCode: CodeGenerator = randomCode,
): Promise<Response> {
  const body = await readBody(req);
  if (body instanceof Response) return body;
  switch (body.action) {
    case 'request':
      return request(body, b, mail, newCode);
    case 'confirm':
      return confirm(body, b);
    default:
      return reply(400, { error: 'unknown_action' });
  }
}

async function request(body: Json, b: Backend, mail: Mailer, newCode: CodeGenerator) {
  if (!mail.configured) return reply(503, { error: 'email_not_configured' });
  const code = str(body, 'user_code');
  if (code === '' || code.length > 20) return reply(400, { error: 'validation_failed' });

  const profile = await b.profileByCode(code);
  if (profile && profile.is_active && profile.contact_email) {
    const value = newCode();
    let send: boolean;
    try {
      send = await b.storeResetCode(profile.id, value);
    } catch (e) {
      if (e instanceof Error && e.message.includes('daily_email_limit')) {
        return reply(429, { error: 'daily_email_limit' });
      }
      throw e;
    }
    if (send) {
      await mail.send(
        profile.contact_email,
        'Diamond Agritech password reset code',
        `Your password reset code is ${value}.\n\n` +
          'It works for 15 minutes. If you did not ask for it, ignore this email.',
      );
    }
  }
  return reply(200, { ok: true });
}

async function confirm(body: Json, b: Backend) {
  const code = str(body, 'user_code');
  const value = str(body, 'code');
  const password = typeof body.new_password === 'string' ? body.new_password : '';
  if (code === '' || !/^[0-9]{6}$/.test(value)) return reply(400, { error: 'invalid_code' });

  const profile = await b.profileByCode(code);
  if (!profile || !profile.is_active) return reply(400, { error: 'invalid_code' });
  const problem = passwordProblem(password, profile.user_code);
  if (problem) return reply(400, { error: 'validation_failed', fields: { new_password: problem } });

  if (!(await b.useResetCode(profile.id, value))) return reply(400, { error: 'invalid_code' });

  await b.setPassword(profile.id, password, { must_change_password: false });
  await b.revokeSessions(profile.id);
  return reply(200, { ok: true });
}
