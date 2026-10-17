// The admin's side: showing a visit photo.
//
//   GET ?visit_id=<uuid>&size=thumb|full   (Authorization: the admin's session)
//
// The photo is fetched from Cloudinary HERE, with a signed address that never
// leaves the function, and the picture itself is returned. No Cloudinary link is
// ever given to a phone: on the Free plan a signed link does not expire, so a
// link that escaped would work for ever. Every view is checked again.

import { deliveryUrl, isPhotoPublicId, isUuid, MAX_PHOTO_BYTES } from './cloudinary.ts';
import type { Deps } from './deps.ts';
import { reply } from './http.ts';

export async function viewRoute(
  auth: string,
  params: URLSearchParams,
  d: Deps,
): Promise<Response> {
  const cloud = d.cloud!;
  if (!(await d.userId(auth))) return reply(401, { error: 'unauthenticated' });
  if (!(await d.isAdmin(auth))) return reply(403, { error: 'forbidden' });

  const visitId = params.get('visit_id');
  const size = params.get('size') ?? 'thumb';
  if (!isUuid(visitId) || (size !== 'thumb' && size !== 'full')) {
    return reply(400, { error: 'validation_failed' });
  }

  const visit = await d.readVisit(auth, visitId);
  if (!visit) return reply(404, { error: 'visit_not_found' });
  if (!visit.photo_public_id) {
    return reply(404, { error: visit.photo_removed_at ? 'photo_removed' : 'no_photo' });
  }
  // Only an id this code made is ever put into a Cloudinary address.
  if (!isPhotoPublicId(visit.photo_public_id)) return reply(500, { error: 'view_failed' });

  let upstream: Response;
  try {
    upstream = await d.fetch(
      await deliveryUrl(cloud.name, cloud.apiSecret, visit.photo_public_id, size),
      { signal: AbortSignal.timeout(8000) },
    );
  } catch {
    return reply(502, { error: 'cloudinary_unavailable' });
  }
  if (upstream.status === 404 || upstream.status === 401 || upstream.status === 403) {
    // The photo is gone from Cloudinary (or never made it): say so, do not guess.
    await upstream.body?.cancel();
    return reply(404, { error: 'photo_unavailable' });
  }
  if (!upstream.ok) {
    await upstream.body?.cancel();
    return reply(502, { error: 'cloudinary_unavailable' });
  }

  const type = upstream.headers.get('content-type') ?? '';
  const length = Number(upstream.headers.get('content-length') ?? 0);
  if (!type.startsWith('image/') || length > MAX_PHOTO_BYTES) {
    await upstream.body?.cancel();
    return reply(502, { error: 'photo_unreadable' });
  }

  return new Response(upstream.body, {
    status: 200,
    headers: {
      'Content-Type': type,
      // The phone may keep it for an hour; nothing else may.
      'Cache-Control': 'private, max-age=3600',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
