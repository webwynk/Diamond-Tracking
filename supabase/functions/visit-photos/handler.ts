// visit-photos: everything about a visit's photo, in one function so it is one
// thing to deploy and review.
//
//   POST {action: "sign" | "confirm", visit_id}   the employee uploads a photo
//   GET  ?visit_id=&size=thumb|full               an admin sees a photo
//   POST {action: "purge"} + x-purge-token        the nightly 90-day deletion
//
// Every route proves who is calling before it does anything else. The platform's
// own JWT check is off for this function only because the nightly job has no
// user session; the user routes check the session here (as create-employee does)
// and the nightly one checks its secret token.
//
// Never logged: photo ids, signatures, tokens, secrets, names.

import type { Deps } from './deps.ts';
import { employeeRoute } from './employee.ts';
import { isUuid } from './cloudinary.ts';
import { reply } from './http.ts';
import { purgeRoute } from './purge.ts';
import { viewRoute } from './view.ts';

export async function handler(req: Request, d: Deps): Promise<Response> {
  try {
    if (!d.cloud) {
      console.error('visit-photos: the Cloudinary secrets are not set');
      return reply(500, { error: 'not_configured' });
    }

    if (req.method === 'GET') {
      const auth = req.headers.get('Authorization');
      if (!auth) return reply(401, { error: 'unauthenticated' });
      return await viewRoute(auth, new URL(req.url).searchParams, d);
    }

    if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' });

    let body: { action?: unknown; visit_id?: unknown };
    try {
      body = await req.json();
    } catch {
      return reply(400, { error: 'validation_failed' });
    }

    if (body.action === 'purge') return await purgeRoute(req, d);

    if (body.action === 'sign' || body.action === 'confirm') {
      const auth = req.headers.get('Authorization');
      if (!auth) return reply(401, { error: 'unauthenticated' });
      if (!isUuid(body.visit_id)) return reply(400, { error: 'validation_failed' });
      return await employeeRoute(auth, body.action, body.visit_id, d);
    }

    return reply(400, { error: 'validation_failed' });
  } catch (error) {
    // Only the kind of failure, never the content.
    console.error('visit-photos failed:', error instanceof Error ? error.name : 'error');
    return reply(500, { error: 'failed' });
  }
}
