import { assert, assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import { deliveryUrl, isPhotoId, signParams } from './cloudinary.ts';
import { handler, type PhotoDeps } from './handler.ts';

const cfg = { cloudName: 'demo', apiKey: 'key1', apiSecret: 'abcd' };
const ID = '11111111-2222-3333-4444-555555555555';

function setup() {
  const b = new FakeBackend();
  const emp = b.addUser({ user_code: 'DA-001' }, 'emp');
  b.addUser({ user_code: 'DA-002' }, 'other');
  b.addUser({ user_code: 'boss', role: 'admin' }, 'admin');
  b.requests.set(5, { owner: emp, photo: `req-${ID}` });
  b.requests.set(6, { owner: emp, photo: null });
  const fetched: string[] = [];
  const deps: PhotoDeps = {
    cloudinary: cfg,
    fetcher: (url) => {
      fetched.push(String(url));
      return Promise.resolve(
        new Response(new Uint8Array([1, 2, 3]), { headers: { 'content-type': 'image/jpeg' } }),
      );
    },
    now: () => 1_700_000_000_000,
    newId: () => ID,
  };
  return { b, deps, fetched };
}

function get(query: string, token?: string): Request {
  return new Request(`http://local/fn?${query}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

Deno.test('Cloudinary documented signature example', async () => {
  // https://cloudinary.com/documentation/authentication_signatures
  assertEquals(
    await signParams(
      {
        eager: 'w_400,h_300,c_pad|w_260,h_200,c_crop',
        public_id: 'sample_image',
        timestamp: '1315060510',
      },
      'abcd',
    ),
    'bfd09f95f331f558cbd1320e67aa8d488770583e',
  );
});

Deno.test('signs an upload with a fresh id', async () => {
  const { b, deps } = setup();
  const res = await handler(post({ action: 'sign' }, 'emp'), b, deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.public_id, `req-${ID}`);
  assertEquals(body.upload_url, 'https://api.cloudinary.com/v1_1/demo/image/upload');
  assertEquals(body.fields.type, 'authenticated');
  assertEquals(body.fields.timestamp, '1700000000');
  assertEquals(body.fields.api_key, 'key1');
  assertEquals(body.fields.signature.length, 40);
  assert(isPhotoId(body.public_id));
});

Deno.test('sign needs a signed-in user and Cloudinary', async () => {
  const { b, deps } = setup();
  assertEquals((await handler(post({ action: 'sign' }), b, deps)).status, 401);
  assertEquals((await handler(post({ action: 'x' }, 'emp'), b, deps)).status, 400);
  assertEquals(
    (await handler(post({ action: 'sign' }, 'emp'), b, { ...deps, cloudinary: null })).status,
    503,
  );
});

Deno.test('the owner and admins see the photo, others do not', async () => {
  const { b, deps, fetched } = setup();
  const own = await handler(get('request_id=5', 'emp'), b, deps);
  assertEquals(own.status, 200);
  assertEquals(new Uint8Array(await own.arrayBuffer()), new Uint8Array([1, 2, 3]));
  assertEquals(fetched[0], await deliveryUrl(cfg, `req-${ID}`));
  assert(fetched[0].startsWith('https://res.cloudinary.com/demo/image/authenticated/s--'));
  assertEquals((await handler(get('request_id=5', 'admin'), b, deps)).status, 200);
  assertEquals((await handler(get('request_id=5', 'other'), b, deps)).status, 403);
  assertEquals((await handler(get('request_id=5'), b, deps)).status, 401);
  assertEquals((await handler(get('request_id=6', 'emp'), b, deps)).status, 404);
  assertEquals((await handler(get('request_id=abc', 'emp'), b, deps)).status, 400);
});
