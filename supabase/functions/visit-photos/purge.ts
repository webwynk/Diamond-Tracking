// The nightly clean-up: photos older than 90 days are deleted (PRD F10).
//
//   POST { "action": "purge" }  with header  x-purge-token: <the shared secret>
//
// Called by the database's scheduler, which has no user session, so the secret
// token is the only credential. A photo is deleted from Cloudinary first and the
// visit row is marked only after that worked (or Cloudinary says it is already
// gone), so a failure is simply tried again tomorrow. The visit itself stays.

import {
  basicAuth,
  destroyEndpoint,
  destroyParams,
  RETENTION_DAYS,
  signParams,
  timingSafeEqual,
} from './cloudinary.ts';
import type { Deps } from './deps.ts';
import { reply } from './http.ts';

/** A night's work is bounded, so one slow night cannot run for ever. */
const BATCH = 100;

export async function purgeRoute(req: Request, d: Deps): Promise<Response> {
  const cloud = d.cloud!;
  const expected = d.purgeToken;
  // An unset token must never mean "anyone".
  if (!expected) return reply(500, { error: 'purge_not_configured' });
  const given = req.headers.get('x-purge-token') ?? '';
  if (!timingSafeEqual(given, expected)) return reply(401, { error: 'unauthenticated' });

  const now = d.now();
  const cutoff = new Date(now.getTime() - RETENTION_DAYS * 86_400_000);
  const due = await d.dueForPurge(cutoff, BATCH);

  let removed = 0;
  let failed = 0;
  for (const photo of due) {
    const timestamp = Math.floor(now.getTime() / 1000);
    const params = destroyParams(photo.photo_public_id, timestamp);
    const form = new URLSearchParams({
      ...params,
      api_key: cloud.apiKey,
      signature: await signParams(params, cloud.apiSecret),
    });
    try {
      const response = await d.fetch(destroyEndpoint(cloud.name), {
        method: 'POST',
        headers: { Authorization: basicAuth(cloud.apiKey, cloud.apiSecret) },
        body: form,
        signal: AbortSignal.timeout(8000),
      });
      const result = (await response.json().catch(() => null)) as { result?: string } | null;
      if (response.ok && (result?.result === 'ok' || result?.result === 'not found')) {
        await d.markPhotoRemoved(photo.id, now);
        removed++;
      } else {
        failed++;
      }
    } catch {
      failed++;
    }
  }

  if (removed > 0 || failed > 0) {
    await d.audit('visit_photos_purged', {
      removed,
      failed,
      older_than: cutoff.toISOString(),
    });
  }
  // `more` tells the next run there is still work, without any person involved.
  return reply(200, { removed, failed, more: due.length === BATCH });
}
