import { assert, assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import {
  deliveryUrl,
  destroyFields,
  isPhotoId,
  signParams,
  THUMBNAIL_TRANSFORMATION,
} from './cloudinary.ts';
import { handler, type PhotoDeps } from './handler.ts';

const cfg = { cloudName: 'demo', apiKey: 'key1', apiSecret: 'abcd' };
const ID = '11111111-2222-3333-4444-555555555555';
const VISIT = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const ID2 = '22222222-2222-3333-4444-555555555555';

function setup() {
  const b = new FakeBackend();
  const emp = b.addUser({ user_code: 'DA-001' }, 'emp');
  b.addUser({ user_code: 'DA-002' }, 'other');
  b.addUser({ user_code: 'boss', role: 'admin' }, 'admin');
  b.requests.set(5, { owner: emp, photo: `req-${ID}`, extra: [`req-${ID2}`] });
  b.requests.set(6, { owner: emp, photo: null });
  b.visits.set(VISIT, { owner: emp, photo: `visit-${VISIT}` });
  const fetched: string[] = [];
  const destroyed: string[] = [];
  const deps: PhotoDeps = {
    cloudinary: cfg,
    fetcher: (url, init) => {
      fetched.push(String(url));
      if (String(url).endsWith('/destroy')) {
        const form = new URLSearchParams(String(init?.body));
        const id = form.get('public_id')!;
        destroyed.push(id);
        if (id.endsWith('9')) return Promise.resolve(new Response('busy', { status: 500 }));
        return Promise.resolve(
          Response.json({ result: id.startsWith('req-') ? 'not found' : 'ok' }),
        );
      }
      return Promise.resolve(
        new Response(new Uint8Array([1, 2, 3]), { headers: { 'content-type': 'image/jpeg' } }),
      );
    },
    now: () => 1_700_000_000_000,
    newId: () => ID,
  };
  return { b, deps, fetched, destroyed };
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

Deno.test("a request's 2nd and 3rd photos are asked for with n", async () => {
  const { b, deps, fetched } = setup();
  assertEquals((await handler(get('request_id=5&n=0', 'emp'), b, deps)).status, 200);
  assertEquals(fetched.at(-1), await deliveryUrl(cfg, `req-${ID}`));
  assertEquals((await handler(get('request_id=5&n=1', 'admin'), b, deps)).status, 200);
  assertEquals(fetched.at(-1), await deliveryUrl(cfg, `req-${ID2}`));
  assertEquals((await handler(get('request_id=5&n=2', 'emp'), b, deps)).status, 404);
  assertEquals((await handler(get('request_id=5&n=1', 'other'), b, deps)).status, 403);
  for (const n of ['3', '-1', 'x', '']) {
    assertEquals((await handler(get(`request_id=5&n=${n}`, 'emp'), b, deps)).status, 400, n);
  }
});

Deno.test('signs a visit photo id', async () => {
  const { b, deps } = setup();
  const res = await handler(post({ action: 'sign', kind: 'visit' }, 'emp'), b, deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.public_id, `visit-${ID}`);
  assertEquals(body.fields.public_id, `visit-${ID}`);
  assert(isPhotoId(body.public_id));
  assertEquals((await handler(post({ action: 'sign', kind: 'x' }, 'emp'), b, deps)).status, 400);
  assert(!isPhotoId('visit-nope'));
  assert(!isPhotoId('other-' + ID));
});

Deno.test('the owner and admins see a visit photo, others do not', async () => {
  const { b, deps, fetched } = setup();
  assertEquals((await handler(get(`visit_id=${VISIT}`, 'emp'), b, deps)).status, 200);
  assertEquals(fetched[0], await deliveryUrl(cfg, `visit-${VISIT}`));
  assertEquals((await handler(get(`visit_id=${VISIT}`, 'admin'), b, deps)).status, 200);
  assertEquals((await handler(get(`visit_id=${VISIT}`, 'other'), b, deps)).status, 403);
  assertEquals((await handler(get(`visit_id=${VISIT}`), b, deps)).status, 401);
  assertEquals((await handler(get('visit_id=1', 'emp'), b, deps)).status, 400);
  b.visits.set(VISIT, { owner: b.tokens.get('emp')!, photo: null }); // removed after 90 days
  assertEquals((await handler(get(`visit_id=${VISIT}`, 'emp'), b, deps)).status, 404);
});

Deno.test('purge deletes old photos and marks the ones that are gone', async () => {
  const { b, deps, destroyed } = setup();
  const failing = `visit-${VISIT.slice(0, -1)}9`;
  b.oldPhotos = [`visit-${VISIT}`, `req-${ID}`, failing, 'bad/path'];
  const res = await handler(post({ action: 'purge' }), b, deps);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { removed: 2, failed: 1 });
  // Photos are deleted a few at a time, so the order of the calls is not fixed.
  assertEquals(destroyed.toSorted(), [`req-${ID}`, `visit-${VISIT}`, failing].toSorted());
  assertEquals(b.removedPhotos, [`visit-${VISIT}`, `req-${ID}`]);
  // Only what is left is tried again.
  destroyed.length = 0;
  await handler(post({ action: 'purge' }), b, deps);
  assertEquals(destroyed, [failing]);
  assertEquals(
    (await handler(post({ action: 'purge' }), b, { ...deps, cloudinary: null })).status,
    503,
  );
});

Deno.test('destroy is signed over invalidate, public_id, timestamp and type', async () => {
  const f = await destroyFields(cfg, `visit-${VISIT}`, 1700000000);
  assertEquals(
    f.signature,
    await signParams(
      {
        invalidate: 'true',
        public_id: `visit-${VISIT}`,
        timestamp: '1700000000',
        type: 'authenticated',
      },
      'abcd',
    ),
  );
  assertEquals(f.api_key, 'key1');
});

Deno.test('Cloudinary shrinks big photos on arrival, inside the signature (L62)', async () => {
  const { b, deps } = setup();
  const body = await (await handler(post({ action: 'sign' }, 'emp'), b, deps)).json();
  assertEquals(body.fields.transformation, 'c_limit,h_1280,w_1280');
  const { api_key: _key, signature, ...signed } = body.fields;
  assertEquals(signature, await signParams(signed, cfg.apiSecret));
});

Deno.test('at most 60 photos a day per person (L62)', async () => {
  const { b, deps } = setup();
  for (let i = 0; i < 60; i++) {
    assertEquals((await handler(post({ action: 'sign' }, 'emp'), b, deps)).status, 200);
  }
  const res = await handler(post({ action: 'sign', kind: 'visit' }, 'emp'), b, deps);
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error, 'photo_limit');
  // Someone else can still upload.
  assertEquals((await handler(post({ action: 'sign' }, 'other'), b, deps)).status, 200);
});

Deno.test('the small version is a signed Cloudinary transformation (L57)', async () => {
  const { b, deps, fetched } = setup();
  const res = await handler(get(`visit_id=${VISIT}&size=small`, 'emp'), b, deps);
  assertEquals(res.status, 200);
  assertEquals(fetched, [await deliveryUrl(cfg, `visit-${VISIT}`, THUMBNAIL_TRANSFORMATION)]);
  assert(fetched[0].endsWith(`--/${THUMBNAIL_TRANSFORMATION}/visit-${VISIT}`));
  // The signature covers the transformation, so it differs from the full one.
  const full = await deliveryUrl(cfg, `visit-${VISIT}`);
  assert(fetched[0].split('/')[6] !== full.split('/')[6]);
  // Requests get it too; anything else than "small" is the full photo.
  await handler(get('request_id=5&size=small', 'emp'), b, deps);
  await handler(get('request_id=5&size=big', 'emp'), b, deps);
  assertEquals(fetched[1], await deliveryUrl(cfg, `req-${ID}`, THUMBNAIL_TRANSFORMATION));
  assertEquals(fetched[2], await deliveryUrl(cfg, `req-${ID}`));
});

Deno.test('when the small version fails, the full photo is sent (L57)', async () => {
  const { b, deps, fetched } = setup();
  for (const fail of ['status', 'throw']) {
    fetched.length = 0;
    const res = await handler(get(`visit_id=${VISIT}&size=small`, 'emp'), b, {
      ...deps,
      fetcher: (url, init) => {
        if (String(url).includes(THUMBNAIL_TRANSFORMATION)) {
          fetched.push(String(url));
          if (fail === 'throw') return Promise.reject(new TypeError('network'));
          return Promise.resolve(new Response('no', { status: 400 }));
        }
        return deps.fetcher(url, init);
      },
    });
    assertEquals(res.status, 200, fail);
    assertEquals(new Uint8Array(await res.arrayBuffer()), new Uint8Array([1, 2, 3]));
    assertEquals(fetched[1], await deliveryUrl(cfg, `visit-${VISIT}`));
  }
});

Deno.test('every signed photo id is noted for the orphan clean-up (L56)', async () => {
  const { b, deps } = setup();
  await handler(post({ action: 'sign', kind: 'visit' }, 'emp'), b, deps);
  await handler(post({ action: 'sign' }, 'emp'), b, deps);
  assertEquals(b.signedPhotos, [`visit-${ID}`, `req-${ID}`]);
  // Noting is not needed to upload: a failure still signs.
  b.failNext.add('noteSignedPhoto');
  const res = await handler(post({ action: 'sign' }, 'emp'), b, deps);
  assertEquals(res.status, 200);
  // Refused uploads are not noted.
  b.photoLimit = 0;
  await handler(post({ action: 'sign' }, 'emp'), b, deps);
  assertEquals(b.signedPhotos.length, 2);
});
