// The employee's side of a visit photo: ask for permission to upload, then
// confirm it arrived.
//
//   POST { "action": "sign",    "visit_id": "<uuid>" }  ->  what to send to Cloudinary
//   POST { "action": "confirm", "visit_id": "<uuid>" }  ->  the photo is attached
//
// Only the employee who made the visit may do either. The phone never chooses
// the photo's id, the delivery type, the formats or the thumbnail: they are all
// in the signature. And the photo is attached only after Cloudinary itself says
// it is there, so nobody can attach an id they did not upload.

import {
  basicAuth,
  MAX_PHOTO_BYTES,
  photoPublicId,
  resourceEndpoint,
  signParams,
  uploadEndpoint,
  uploadParams,
} from './cloudinary.ts';
import type { Deps, VisitRow } from './deps.ts';
import { reply } from './http.ts';

/** A visit older than this can no longer get a photo (the offline queue is days, not weeks). */
const MAX_VISIT_AGE_DAYS = 14;

const FORMATS = ['jpg', 'jpeg', 'png', 'webp'];

export async function employeeRoute(
  auth: string,
  action: 'sign' | 'confirm',
  visitId: string,
  d: Deps,
): Promise<Response> {
  const cloud = d.cloud!;
  const userId = await d.userId(auth);
  if (!userId) return reply(401, { error: 'unauthenticated' });

  const visit = await d.readVisit(auth, visitId);
  if (!visit) return reply(404, { error: 'visit_not_found' });
  // An admin can read every visit, but only its own employee may add a photo.
  if (visit.employee_id !== userId) return reply(403, { error: 'forbidden' });
  if (visit.photo_removed_at) return reply(409, { error: 'photo_expired' });

  return action === 'sign'
    ? await sign(visit, d, cloud.name, cloud.apiKey, cloud.apiSecret)
    : await confirm(visit, d, cloud.name, cloud.apiKey, cloud.apiSecret);
}

async function sign(
  visit: VisitRow,
  d: Deps,
  cloudName: string,
  apiKey: string,
  apiSecret: string,
): Promise<Response> {
  if (visit.photo_public_id) return reply(409, { error: 'photo_already_attached' });

  const ageDays = (d.now().getTime() - new Date(visit.created_at).getTime()) / 86_400_000;
  if (ageDays > MAX_VISIT_AGE_DAYS) return reply(409, { error: 'visit_too_old' });

  const params = uploadParams(visit.id, Math.floor(d.now().getTime() / 1000));
  return reply(200, {
    upload_url: uploadEndpoint(cloudName),
    api_key: apiKey,
    params,
    signature: await signParams(params, apiSecret),
  });
}

async function confirm(
  visit: VisitRow,
  d: Deps,
  cloudName: string,
  apiKey: string,
  apiSecret: string,
): Promise<Response> {
  const publicId = photoPublicId(visit.id);
  // Confirming twice is fine.
  if (visit.photo_public_id === publicId) return reply(200, { status: 'attached' });
  if (visit.photo_public_id) return reply(409, { error: 'photo_already_attached' });

  let found: Response;
  try {
    found = await d.fetch(resourceEndpoint(cloudName, publicId), {
      headers: { Authorization: basicAuth(apiKey, apiSecret) },
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    return reply(502, { error: 'cloudinary_unavailable' });
  }
  if (found.status === 404) return reply(409, { error: 'photo_not_uploaded' });
  if (!found.ok) return reply(502, { error: 'cloudinary_unavailable' });

  const asset = await found.json().catch(() => null) as
    | { public_id?: string; type?: string; format?: string; bytes?: number }
    | null;
  if (
    !asset ||
    asset.public_id !== publicId ||
    asset.type !== 'authenticated' ||
    !FORMATS.includes(String(asset.format).toLowerCase()) ||
    typeof asset.bytes !== 'number' ||
    asset.bytes > MAX_PHOTO_BYTES
  ) {
    return reply(422, { error: 'photo_rejected' });
  }

  const attached = await d.attachPhoto(visit.id, publicId, d.now());
  if (!attached) return reply(409, { error: 'photo_already_attached' });
  return reply(200, { status: 'attached' });
}
