import type { Backend, Profile } from './backend.ts';
import { bearer, reply } from './http.ts';

/** The signed-in caller's profile, or the reply to send if there is none. */
export async function callerProfile(
  req: Request,
  b: Backend,
): Promise<{ profile: Profile; appMetadata: Record<string, unknown> } | Response> {
  const token = bearer(req);
  if (!token) return reply(401, { error: 'not_signed_in' });
  const user = await b.userFromToken(token);
  if (!user) return reply(401, { error: 'not_signed_in' });
  const profile = await b.profile(user.id);
  if (!profile || !profile.is_active) return reply(403, { error: 'account_inactive' });
  return { profile, appMetadata: user.appMetadata };
}
