// push: sends one notification to the user's phones.
//
//   POST { id }   called by the database for every new notification
//        200 { sent, dropped }
//
// No secret is needed: the database hands out each notification once, so a
// caller can only cause a push that was going to be sent anyway.
import type { Backend } from '../_shared/backend.ts';
import { readBody, reply } from '../_shared/http.ts';
import type { PushMessage, Sender } from './fcm.ts';

export async function handler(req: Request, b: Backend, sender: Sender | null): Promise<Response> {
  const body = await readBody(req);
  if (body instanceof Response) return body;
  const id = body.id;
  if (typeof id !== 'number' || !Number.isSafeInteger(id) || id <= 0) {
    return reply(400, { error: 'validation_failed' });
  }
  // Without Firebase set up, leave the notification unclaimed (in-app only).
  if (!sender) return reply(200, { sent: 0, dropped: 0 });

  const job = await b.claimPush(id);
  if (!job || job.tokens.length === 0) return reply(200, { sent: 0, dropped: 0 });

  const message: PushMessage = {
    title: job.title,
    body: job.body,
    data: Object.fromEntries(
      Object.entries({ ...job.data, kind: job.kind }).map(([k, v]) => [k, String(v)]),
    ),
  };
  // Each phone on its own: a network error for one phone must not lose the
  // push for the others, nor skip dropping dead tokens (L64).
  const results = await Promise.all(job.tokens.map(async (t) => {
    try {
      return await sender.send(t, message);
    } catch (e) {
      console.error('push to one phone failed:', e instanceof Error ? e.message : 'unknown');
      return 'failed' as const;
    }
  }));
  const gone = job.tokens.filter((_, i) => results[i] === 'gone');
  if (gone.length > 0) await b.dropPushTokens(gone);
  return reply(200, { sent: results.filter((r) => r === 'sent').length, dropped: gone.length });
}
