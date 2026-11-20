// photos: request photos (attendance and leave proof) and visit photos.
//
//   POST { action: "sign" }                  any signed-in user
//   POST { action: "sign", kind: "visit" }   any signed-in user
//        200 { upload_url, public_id, fields }   the phone posts the file
//        with these fields straight to Cloudinary, then sends public_id with
//        its request. A visit photo id is "visit-<uuid>"; that uuid is the
//        visit's id.
//   GET  ?request_id=N | ?visit_id=<uuid>    the owner or an admin
//        200 the image bytes
//   POST { action: "purge" }                 no sign-in (the nightly job)
//        Deletes photos older than 90 days. Only the database decides which,
//        so calling it early does nothing.
//        200 { removed, failed }
import type { Backend } from '../_shared/backend.ts';
import { callerProfile } from '../_shared/caller.ts';
import { readBody, reply } from '../_shared/http.ts';
import {
  type CloudinaryConfig,
  deliveryUrl,
  destroyFields,
  destroyUrl,
  isPhotoId,
  isUuid,
  uploadFields,
  uploadUrl,
} from './cloudinary.ts';

export interface PhotoDeps {
  cloudinary: CloudinaryConfig | null;
  fetcher: typeof fetch;
  now: () => number;
  newId: () => string;
}

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

/** Photos deleted per purge call, and how many at once. */
const PURGE_BATCH = 200;
const PURGE_PARALLEL = 5;

export async function handler(req: Request, b: Backend, deps: PhotoDeps): Promise<Response> {
  if (req.method === 'GET') return await view(req, b, deps);
  const body = await readBody(req);
  if (body instanceof Response) return body;
  if (body.action === 'purge') return await purge(b, deps);
  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;
  if (body.action !== 'sign') return reply(400, { error: 'validation_failed' });
  if (body.kind !== undefined && body.kind !== 'request' && body.kind !== 'visit') {
    return reply(400, { error: 'validation_failed' });
  }
  const cfg = deps.cloudinary;
  if (!cfg) return reply(503, { error: 'photos_not_configured' });

  const publicId = `${body.kind === 'visit' ? 'visit' : 'req'}-${deps.newId()}`;
  return reply(200, {
    upload_url: uploadUrl(cfg.cloudName),
    public_id: publicId,
    fields: await uploadFields(cfg, publicId, Math.floor(deps.now() / 1000)),
  });
}

async function view(req: Request, b: Backend, deps: PhotoDeps): Promise<Response> {
  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;
  const params = new URL(req.url).searchParams;
  let photo: string | null | 'not_allowed';
  if (params.has('visit_id')) {
    const visitId = params.get('visit_id') ?? '';
    if (!isUuid(visitId)) return reply(400, { error: 'validation_failed' });
    photo = await b.visitPhoto(visitId, caller.profile.id);
  } else {
    const raw = params.get('request_id') ?? '';
    const requestId = /^[1-9][0-9]{0,15}$/.test(raw) ? Number(raw) : NaN;
    if (!Number.isSafeInteger(requestId)) return reply(400, { error: 'validation_failed' });
    photo = await b.requestPhoto(requestId, caller.profile.id);
  }
  if (photo === 'not_allowed') return reply(403, { error: 'not_allowed' });
  if (!photo || !isPhotoId(photo)) return reply(404, { error: 'no_photo' });
  const cfg = deps.cloudinary;
  if (!cfg) return reply(503, { error: 'photos_not_configured' });

  const res = await deps.fetcher(await deliveryUrl(cfg, photo), {
    signal: AbortSignal.timeout(15000),
  });
  if (res.status === 404) return reply(404, { error: 'no_photo' });
  if (!res.ok || !res.body) return reply(502, { error: 'photo_unavailable' });
  return new Response(res.body, {
    status: 200,
    headers: {
      'content-type': res.headers.get('content-type') ?? 'image/jpeg',
      'cache-control': 'private, max-age=86400',
      ...CORS,
    },
  });
}

async function purge(b: Backend, deps: PhotoDeps): Promise<Response> {
  const cfg = deps.cloudinary;
  if (!cfg) return reply(503, { error: 'photos_not_configured' });
  const ids = (await b.photosToPurge(PURGE_BATCH)).filter(isPhotoId);
  const removed: string[] = [];
  let failed = 0;
  for (let i = 0; i < ids.length; i += PURGE_PARALLEL) {
    const batch = ids.slice(i, i + PURGE_PARALLEL);
    const results = await Promise.all(batch.map((id) => destroy(cfg, id, deps)));
    batch.forEach((id, j) => (results[j] ? removed.push(id) : failed++));
  }
  if (removed.length) await b.photosRemoved(removed);
  return reply(200, { removed: removed.length, failed });
}

/** True when the photo is gone from Cloudinary (deleted now or before). */
async function destroy(cfg: CloudinaryConfig, publicId: string, deps: PhotoDeps) {
  try {
    const fields = await destroyFields(cfg, publicId, Math.floor(deps.now() / 1000));
    const res = await deps.fetcher(destroyUrl(cfg.cloudName), {
      method: 'POST',
      body: new URLSearchParams(fields),
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return false;
    const result = (await res.json())?.result;
    return result === 'ok' || result === 'not found';
  } catch {
    return false;
  }
}
