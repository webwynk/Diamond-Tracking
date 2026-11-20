// photos: request photos (attendance proof, leave proof).
//
//   POST { action: "sign" }            any signed-in user
//        200 { upload_url, public_id, fields }   the phone posts the file
//        with these fields straight to Cloudinary, then sends public_id with
//        its request.
//   GET  ?request_id=N                 the request's owner or an admin
//        200 the image bytes
import type { Backend } from '../_shared/backend.ts';
import { callerProfile } from '../_shared/caller.ts';
import { readBody, reply } from '../_shared/http.ts';
import {
  type CloudinaryConfig,
  deliveryUrl,
  isPhotoId,
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

export async function handler(req: Request, b: Backend, deps: PhotoDeps): Promise<Response> {
  if (req.method === 'GET') return await view(req, b, deps);
  const body = await readBody(req);
  if (body instanceof Response) return body;
  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;
  if (body.action !== 'sign') return reply(400, { error: 'validation_failed' });
  const cfg = deps.cloudinary;
  if (!cfg) return reply(503, { error: 'photos_not_configured' });

  const publicId = `req-${deps.newId()}`;
  return reply(200, {
    upload_url: uploadUrl(cfg.cloudName),
    public_id: publicId,
    fields: await uploadFields(cfg, publicId, Math.floor(deps.now() / 1000)),
  });
}

async function view(req: Request, b: Backend, deps: PhotoDeps): Promise<Response> {
  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;
  const raw = new URL(req.url).searchParams.get('request_id') ?? '';
  const requestId = /^[1-9][0-9]{0,15}$/.test(raw) ? Number(raw) : NaN;
  if (!Number.isSafeInteger(requestId)) return reply(400, { error: 'validation_failed' });

  const photo = await b.requestPhoto(requestId, caller.profile.id);
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
