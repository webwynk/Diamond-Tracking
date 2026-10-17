// deno test supabase/functions/visit-photos
import { createHash } from 'node:crypto';
import { assertEquals, assertMatch, assertNotEquals, assertThrows } from 'jsr:@std/assert@1';
import {
  ALLOWED_FORMATS,
  deliveryUrl,
  destroyParams,
  isPhotoPublicId,
  isUuid,
  photoPublicId,
  signParams,
  THUMB_TRANSFORMATION,
  timingSafeEqual,
  uploadParams,
} from './cloudinary.ts';

const VISIT = '3f2b8c1e-9a4d-4c7e-b1f0-6d5a2e8c9b04';

// A second, independent way of computing the same thing.
const sha1Hex = (s: string) => createHash('sha1').update(s).digest('hex');
const sha1Base64Url = (s: string) =>
  createHash('sha1').update(s).digest('base64').replaceAll('+', '-').replaceAll('/', '_')
    .replaceAll('=', '');

Deno.test('signParams: sorted name=value pairs joined with &, secret appended, SHA-1 hex', async () => {
  const signature = await signParams({ timestamp: '1315060510', public_id: 'sample', eager: 'w_400' }, 'abcd');

  assertEquals(signature, sha1Hex('eager=w_400&public_id=sample&timestamp=1315060510abcd'));
});

Deno.test('signParams: the documented single-parameter example', async () => {
  // Cloudinary documents `timestamp=1315060510` + secret `abcd` signing as one string.
  assertEquals(await signParams({ timestamp: '1315060510' }, 'abcd'), sha1Hex('timestamp=1315060510abcd'));
});

Deno.test('signParams: empty and missing values are left out', async () => {
  const withEmpty = await signParams({ a: '1', b: '', c: undefined }, 's');
  const without = await signParams({ a: '1' }, 's');

  assertEquals(withEmpty, without);
});

Deno.test('signParams: a different secret or value gives a different signature', async () => {
  const base = await signParams({ a: '1' }, 's');

  assertNotEquals(await signParams({ a: '1' }, 't'), base);
  assertNotEquals(await signParams({ a: '2' }, 's'), base);
});

Deno.test('uploadParams: everything the phone may not choose is fixed and signed', () => {
  const params = uploadParams(VISIT, 1_760_000_000);

  assertEquals(params, {
    allowed_formats: ALLOWED_FORMATS,
    eager: THUMB_TRANSFORMATION,
    overwrite: 'true',
    public_id: `visit-${VISIT}`,
    timestamp: '1760000000',
    type: 'authenticated',
  });
});

Deno.test('uploadParams: only a UUID can name a photo', () => {
  assertThrows(() => uploadParams('../../other', 1));
  assertThrows(() => uploadParams('', 1));
});

Deno.test('photoPublicId: lower-cases, and only an id made here is trusted back', () => {
  assertEquals(photoPublicId(VISIT.toUpperCase()), `visit-${VISIT}`);
  assertEquals(isPhotoPublicId(`visit-${VISIT}`), true);
  assertEquals(isPhotoPublicId(`visit-${VISIT}/../x`), false);
  assertEquals(isPhotoPublicId('something-else'), false);
  assertEquals(isPhotoPublicId(null), false);
});

Deno.test('isUuid', () => {
  assertEquals(isUuid(VISIT), true);
  assertEquals(isUuid('not-a-uuid'), false);
  assertEquals(isUuid(123), false);
});

Deno.test('destroyParams: authenticated, invalidated, signed over these four', () => {
  assertEquals(destroyParams('visit-x', 5), {
    invalidate: 'true',
    public_id: 'visit-x',
    timestamp: '5',
    type: 'authenticated',
  });
});

Deno.test('deliveryUrl: the thumbnail is signed over transformation/public_id', async () => {
  const id = `visit-${VISIT}`;
  const url = await deliveryUrl('demo', 'secret', id, 'thumb');

  const signature = sha1Base64Url(`${THUMB_TRANSFORMATION}/${id}secret`).slice(0, 8);
  assertEquals(
    url,
    `https://res.cloudinary.com/demo/image/authenticated/s--${signature}--/${THUMB_TRANSFORMATION}/${id}`,
  );
});

Deno.test('deliveryUrl: the full photo has no transformation and its own signature', async () => {
  const id = `visit-${VISIT}`;
  const url = await deliveryUrl('demo', 'secret', id, 'full');

  const signature = sha1Base64Url(`${id}secret`).slice(0, 8);
  assertEquals(url, `https://res.cloudinary.com/demo/image/authenticated/s--${signature}--/${id}`);
});

Deno.test('deliveryUrl: the signature is 8 URL-safe characters and depends on the secret', async () => {
  const id = `visit-${VISIT}`;
  const a = await deliveryUrl('demo', 'secret', id, 'thumb');
  const b = await deliveryUrl('demo', 'other', id, 'thumb');

  assertMatch(a, /\/s--[A-Za-z0-9_-]{8}--\//);
  assertNotEquals(a, b);
});

Deno.test('timingSafeEqual', () => {
  assertEquals(timingSafeEqual('abc', 'abc'), true);
  assertEquals(timingSafeEqual('abc', 'abd'), false);
  assertEquals(timingSafeEqual('abc', 'abcd'), false);
  assertEquals(timingSafeEqual('', 'a'), false);
});
