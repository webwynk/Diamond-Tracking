// Cloudinary signing. Pure: the secret is passed in, nothing is fetched.
//   * Photos are uploaded as type `authenticated`, so every address needs a
//     signature made with the API secret, which never leaves the server.
//   * The phone uploads straight to Cloudinary with parameters signed here,
//     so it cannot change the id, the type or the formats.

export interface CloudinaryConfig {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
}

export const ALLOWED_FORMATS = 'jpg,jpeg,png,webp';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID.test(value);
}

/** True for an id the photos function hands out: `req-<uuid>` or `visit-<uuid>`. */
export function isPhotoId(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  if (value.startsWith('req-')) return UUID.test(value.slice(4));
  if (value.startsWith('visit-')) return UUID.test(value.slice(6));
  return false;
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
 * Every parameter as `name=value`, sorted by name, joined with `&`, the secret
 * added at the end, then SHA-1 as hex. Empty values are left out.
 */
export async function signParams(
  params: Record<string, string>,
  apiSecret: string,
): Promise<string> {
  const toSign = Object.entries(params)
    .filter(([, v]) => v !== '')
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${k}=${v}`)
    .join('&');
  return hex(await sha1(toSign + apiSecret));
}

/** The form fields of one signed upload. */
export async function uploadFields(
  cfg: CloudinaryConfig,
  publicId: string,
  timestamp: number,
): Promise<Record<string, string>> {
  const params = {
    allowed_formats: ALLOWED_FORMATS,
    public_id: publicId,
    timestamp: String(timestamp),
    type: 'authenticated',
  };
  return { ...params, api_key: cfg.apiKey, signature: await signParams(params, cfg.apiSecret) };
}

/** The form fields that delete one photo (and clear it from the CDN). */
export async function destroyFields(
  cfg: CloudinaryConfig,
  publicId: string,
  timestamp: number,
): Promise<Record<string, string>> {
  const params = {
    invalidate: 'true',
    public_id: publicId,
    timestamp: String(timestamp),
    type: 'authenticated',
  };
  return { ...params, api_key: cfg.apiKey, signature: await signParams(params, cfg.apiSecret) };
}

export function destroyUrl(cloudName: string): string {
  return `https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`;
}

export function uploadUrl(cloudName: string): string {
  return `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`;
}

/**
 * The signed address of a photo: the first 8 characters of the URL-safe
 * base64 of SHA-1 over the public id plus the secret. It does not expire, so it
 * stays on the server; the function passes the bytes on instead.
 */
export async function deliveryUrl(cfg: CloudinaryConfig, publicId: string): Promise<string> {
  const signature = base64Url(await sha1(publicId + cfg.apiSecret)).slice(0, 8);
  return `https://res.cloudinary.com/${cfg.cloudName}/image/authenticated/s--${signature}--/${publicId}`;
}
