// Cloudinary helpers shared by the visit-photo functions.
//
// Pure: no network and no secret of their own (the secret is passed in), so
// they can be tested without Cloudinary. Why each choice is made is in
// docs/10-CLOUDINARY-BEST-PRACTICES.md; the points that matter here:
//   * Photos are delivered as type `authenticated`: every URL needs a signature.
//   * An authenticated photo cannot be resized on the fly. The thumbnail must be
//     asked for in the signed upload (`eager`) and fetched with the same
//     transformation string, which is why it is a constant here.
//   * Signatures made with the API secret never leave the server.

/** Formats a visit photo may have. The app sends a JPEG. */
export const ALLOWED_FORMATS = 'jpg,jpeg,png,webp';

/** The one thumbnail, made when the photo is uploaded (alphabetical, as the SDKs write it). */
export const THUMB_TRANSFORMATION = 'c_fill,f_jpg,h_240,q_80,w_240';

/** A compressed visit photo is about 200 KB; anything over this is refused. */
export const MAX_PHOTO_BYTES = 2_000_000;

/** Photos older than this are deleted (PRD F10). */
export const RETENTION_DAYS = 90;

export type PhotoSize = 'thumb' | 'full';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID.test(value);
}

/**
 * The photo's Cloudinary id, made from the visit's id so a retried upload
 * overwrites instead of creating a second photo. Throws on anything that is not
 * a UUID, so no other text can ever reach a Cloudinary path.
 */
export function photoPublicId(visitId: string): string {
  if (!isUuid(visitId)) throw new Error('invalid_visit_id');
  return `visit-${visitId.toLowerCase()}`;
}

/** True for an id this code made: `visit-<uuid>`. */
export function isPhotoPublicId(value: unknown): value is string {
  return typeof value === 'string' &&
    value.startsWith('visit-') &&
    isUuid(value.slice('visit-'.length));
}

const encoder = new TextEncoder();

async function sha1(text: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest('SHA-1', encoder.encode(text)));
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

/**
 * The signature of an upload or API call: every parameter except `file`,
 * `cloud_name`, `resource_type` and `api_key`, as `name=value`, sorted by name
 * and joined with `&`, with the API secret added at the end, then SHA-1 as hex.
 * Empty values are left out, as Cloudinary does.
 */
export async function signParams(
  params: Record<string, string | undefined>,
  apiSecret: string,
): Promise<string> {
  const toSign = Object.entries(params)
    .filter(([, value]) => value !== undefined && value !== '')
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([name, value]) => `${name}=${value}`)
    .join('&');
  return hex(await sha1(toSign + apiSecret));
}

/**
 * What the phone is allowed to upload. All of it is signed, so the phone cannot
 * change the id, the delivery type, the formats or the thumbnail.
 */
export function uploadParams(visitId: string, timestamp: number): Record<string, string> {
  return {
    allowed_formats: ALLOWED_FORMATS,
    eager: THUMB_TRANSFORMATION,
    overwrite: 'true',
    public_id: photoPublicId(visitId),
    timestamp: String(timestamp),
    type: 'authenticated',
  };
}

/** The parameters of deleting one photo and its thumbnail. */
export function destroyParams(publicId: string, timestamp: number): Record<string, string> {
  return {
    invalidate: 'true',
    public_id: publicId,
    timestamp: String(timestamp),
    type: 'authenticated',
  };
}

/**
 * The signed address of a photo. The signature is the first 8 characters of the
 * URL-safe base64 of SHA-1 over `[transformation/]public_id` plus the secret.
 * It does not expire (on the Free plan only token access expires, and that is an
 * Advanced feature), so this address is used only inside the admin-only function
 * and never handed to a phone.
 */
export async function deliveryUrl(
  cloudName: string,
  apiSecret: string,
  publicId: string,
  size: PhotoSize,
): Promise<string> {
  const transformation = size === 'thumb' ? THUMB_TRANSFORMATION : '';
  const toSign = [transformation, publicId].filter(Boolean).join('/');
  const signature = base64Url(await sha1(toSign + apiSecret)).slice(0, 8);
  const path = [`s--${signature}--`, transformation, publicId].filter(Boolean).join('/');
  return `https://res.cloudinary.com/${cloudName}/image/authenticated/${path}`;
}

export function uploadEndpoint(cloudName: string): string {
  return `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`;
}

export function destroyEndpoint(cloudName: string): string {
  return `https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`;
}

/** The Admin API address that describes one photo. */
export function resourceEndpoint(cloudName: string, publicId: string): string {
  return `https://api.cloudinary.com/v1_1/${cloudName}/resources/image/authenticated/${publicId}`;
}

export function basicAuth(apiKey: string, apiSecret: string): string {
  return 'Basic ' + btoa(`${apiKey}:${apiSecret}`);
}

/** Compares two secrets without stopping at the first difference. */
export function timingSafeEqual(a: string, b: string): boolean {
  const x = encoder.encode(a);
  const y = encoder.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}
