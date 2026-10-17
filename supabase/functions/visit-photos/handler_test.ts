// deno test supabase/functions/visit-photos
import { assertEquals, assertMatch, assertNotEquals } from 'jsr:@std/assert@1';
import { signParams, THUMB_TRANSFORMATION } from './cloudinary.ts';
import type { Deps, DuePhoto, VisitRow } from './deps.ts';
import { handler } from './handler.ts';

const NOW = new Date('2026-10-18T10:00:00Z');
const VISIT = '3f2b8c1e-9a4d-4c7e-b1f0-6d5a2e8c9b04';
const OTHER_VISIT = '7a1d2c3e-1111-4222-8333-444455556666';
const PUBLIC_ID = `visit-${VISIT}`;

/** Who each test token belongs to. */
const SESSIONS: Record<string, { id: string; admin: boolean }> = {
  'Bearer emp': { id: 'e1', admin: false },
  'Bearer emp2': { id: 'e2', admin: false },
  'Bearer admin': { id: 'a1', admin: true },
};

function visit(overrides: Partial<VisitRow> = {}): VisitRow {
  return {
    id: VISIT,
    employee_id: 'e1',
    photo_public_id: null,
    photo_removed_at: null,
    created_at: '2026-10-18T09:00:00Z',
    ...overrides,
  };
}

type Calls = {
  attached: Array<[string, string]>;
  removed: string[];
  audits: Array<[string, Record<string, unknown>]>;
  fetched: Array<{ url: string; init?: RequestInit }>;
  dueArgs: Array<[Date, number]>;
};

function fakeDeps(
  options: {
    visits?: VisitRow[];
    cloud?: Deps['cloud'];
    purgeToken?: string | null;
    fetch?: (url: string, init?: RequestInit) => Promise<Response> | Response;
    attach?: boolean;
    due?: DuePhoto[];
  } = {},
): { deps: Deps; calls: Calls } {
  const visits = options.visits ?? [visit()];
  const calls: Calls = { attached: [], removed: [], audits: [], fetched: [], dueArgs: [] };
  const deps: Deps = {
    cloud: options.cloud === undefined
      ? { name: 'demo', apiKey: 'key', apiSecret: 'secret' }
      : options.cloud,
    purgeToken: options.purgeToken === undefined ? 'nightly' : options.purgeToken,
    now: () => NOW,
    fetch: (url, init) => {
      calls.fetched.push({ url, init });
      if (!options.fetch) throw new Error('unexpected network call');
      return Promise.resolve(options.fetch(url, init));
    },
    userId: (auth) => Promise.resolve(SESSIONS[auth]?.id ?? null),
    isAdmin: (auth) => Promise.resolve(SESSIONS[auth]?.admin === true),
    // Row-level security: an employee sees their own visits, an admin sees all.
    readVisit: (auth, id) => {
      const session = SESSIONS[auth];
      const row = visits.find((v) => v.id === id);
      if (!session || !row) return Promise.resolve(null);
      return Promise.resolve(session.admin || row.employee_id === session.id ? row : null);
    },
    attachPhoto: (id, publicId) => {
      calls.attached.push([id, publicId]);
      return Promise.resolve(options.attach ?? true);
    },
    dueForPurge: (cutoff, limit) => {
      calls.dueArgs.push([cutoff, limit]);
      return Promise.resolve(options.due ?? []);
    },
    markPhotoRemoved: (id) => {
      calls.removed.push(id);
      return Promise.resolve();
    },
    audit: (action, details) => {
      calls.audits.push([action, details]);
      return Promise.resolve();
    },
  };
  return { deps, calls };
}

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request('https://f.test/visit-photos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

function get(query: string, headers: Record<string, string> = {}): Request {
  return new Request(`https://f.test/visit-photos?${query}`, { method: 'GET', headers });
}

const json = (r: Response) => r.json() as Promise<Record<string, unknown>>;

// -----------------------------------------------------------------------------
// The router
// -----------------------------------------------------------------------------

Deno.test('router: missing Cloudinary secrets is a plain failure, for every route', async () => {
  const { deps } = fakeDeps({ cloud: null });

  assertEquals((await handler(post({ action: 'sign', visit_id: VISIT }, { Authorization: 'Bearer emp' }), deps)).status, 500);
  assertEquals((await handler(get(`visit_id=${VISIT}`, { Authorization: 'Bearer admin' }), deps)).status, 500);
});

Deno.test('router: other methods are refused', async () => {
  const { deps } = fakeDeps();

  const response = await handler(new Request('https://f.test/', { method: 'DELETE' }), deps);

  assertEquals(response.status, 405);
});

Deno.test('router: a body that is not JSON, or an unknown action, is a 400', async () => {
  const { deps } = fakeDeps();

  assertEquals((await handler(post('{nope'), deps)).status, 400);
  assertEquals((await handler(post({ action: 'delete', visit_id: VISIT }, { Authorization: 'Bearer emp' }), deps)).status, 400);
});

Deno.test('router: sign and confirm need a session and a UUID', async () => {
  const { deps } = fakeDeps();

  assertEquals((await handler(post({ action: 'sign', visit_id: VISIT }), deps)).status, 401);
  assertEquals((await handler(post({ action: 'sign', visit_id: 'nope' }, { Authorization: 'Bearer emp' }), deps)).status, 400);
  assertEquals((await handler(post({ action: 'sign', visit_id: VISIT }, { Authorization: 'Bearer garbage' }), deps)).status, 401);
});

// -----------------------------------------------------------------------------
// sign
// -----------------------------------------------------------------------------

const sign = (auth: string, deps: Deps, id = VISIT) =>
  handler(post({ action: 'sign', visit_id: id }, { Authorization: auth }), deps);

Deno.test('sign: the employee gets exactly what to send, signed', async () => {
  const { deps } = fakeDeps();

  const response = await sign('Bearer emp', deps);
  const body = await json(response);

  assertEquals(response.status, 200);
  assertEquals(body.upload_url, 'https://api.cloudinary.com/v1_1/demo/image/upload');
  assertEquals(body.api_key, 'key');
  const params = body.params as Record<string, string>;
  assertEquals(params.public_id, PUBLIC_ID);
  assertEquals(params.type, 'authenticated');
  assertEquals(params.eager, THUMB_TRANSFORMATION);
  assertEquals(params.timestamp, String(Math.floor(NOW.getTime() / 1000)));
  assertEquals(body.signature, await signParams(params, 'secret'));
});

Deno.test('sign: the response never contains the API secret', async () => {
  const { deps } = fakeDeps();

  const text = await (await sign('Bearer emp', deps)).text();

  assertEquals(text.includes('secret'), false);
});

Deno.test('sign: another employee cannot see the visit, so cannot sign for it', async () => {
  const { deps } = fakeDeps();

  assertEquals((await sign('Bearer emp2', deps)).status, 404);
});

Deno.test('sign: an admin can read the visit but may not add a photo to it', async () => {
  const { deps } = fakeDeps();

  assertEquals((await sign('Bearer admin', deps)).status, 403);
});

Deno.test('sign: a visit that does not exist', async () => {
  const { deps } = fakeDeps();

  assertEquals((await sign('Bearer emp', deps, OTHER_VISIT)).status, 404);
});

Deno.test('sign: a visit that already has a photo, or lost it, or is too old', async () => {
  const has = fakeDeps({ visits: [visit({ photo_public_id: PUBLIC_ID })] });
  const gone = fakeDeps({ visits: [visit({ photo_removed_at: '2026-10-01T00:00:00Z' })] });
  const old = fakeDeps({ visits: [visit({ created_at: '2026-09-01T00:00:00Z' })] });

  const a = await sign('Bearer emp', has.deps);
  const b = await sign('Bearer emp', gone.deps);
  const c = await sign('Bearer emp', old.deps);

  assertEquals([a.status, (await json(a)).error], [409, 'photo_already_attached']);
  assertEquals([b.status, (await json(b)).error], [409, 'photo_expired']);
  assertEquals([c.status, (await json(c)).error], [409, 'visit_too_old']);
});

// -----------------------------------------------------------------------------
// confirm
// -----------------------------------------------------------------------------

const confirm = (auth: string, deps: Deps, id = VISIT) =>
  handler(post({ action: 'confirm', visit_id: id }, { Authorization: auth }), deps);

const asset = (overrides: Record<string, unknown> = {}) =>
  new Response(
    JSON.stringify({ public_id: PUBLIC_ID, type: 'authenticated', format: 'jpg', bytes: 180_000, ...overrides }),
    { status: 200 },
  );

Deno.test('confirm: Cloudinary has the photo, so it is attached', async () => {
  const { deps, calls } = fakeDeps({ fetch: () => asset() });

  const response = await confirm('Bearer emp', deps);

  assertEquals(response.status, 200);
  assertEquals(calls.attached, [[VISIT, PUBLIC_ID]]);
  assertEquals(calls.fetched[0].url, `https://api.cloudinary.com/v1_1/demo/resources/image/authenticated/${PUBLIC_ID}`);
  assertEquals(
    (calls.fetched[0].init?.headers as Record<string, string>).Authorization,
    'Basic ' + btoa('key:secret'),
  );
});

Deno.test('confirm: twice is fine and asks nothing of Cloudinary the second time', async () => {
  const { deps, calls } = fakeDeps({ visits: [visit({ photo_public_id: PUBLIC_ID })] });

  const response = await confirm('Bearer emp', deps);

  assertEquals(response.status, 200);
  assertEquals(calls.fetched.length, 0);
  assertEquals(calls.attached.length, 0);
});

Deno.test('confirm: nothing was uploaded yet is a 409 the app can retry', async () => {
  const { deps, calls } = fakeDeps({ fetch: () => new Response('{}', { status: 404 }) });

  const response = await confirm('Bearer emp', deps);

  assertEquals([response.status, (await json(response)).error], [409, 'photo_not_uploaded']);
  assertEquals(calls.attached.length, 0);
});

Deno.test('confirm: an asset that is not what was asked for is refused and not attached', async () => {
  const cases: Array<Record<string, unknown>> = [
    { type: 'upload' }, // public, not authenticated
    { format: 'gif' },
    { format: 'pdf' },
    { bytes: 5_000_000 },
    { bytes: 'big' },
    { public_id: 'visit-someone-else' },
  ];
  for (const wrong of cases) {
    const { deps, calls } = fakeDeps({ fetch: () => asset(wrong) });

    const response = await confirm('Bearer emp', deps);

    assertEquals([response.status, (await json(response)).error, calls.attached.length], [422, 'photo_rejected', 0], JSON.stringify(wrong));
  }
});

Deno.test('confirm: Cloudinary down is a 502, never a half-attached photo', async () => {
  const down = fakeDeps({ fetch: () => new Response('', { status: 500 }) });
  const broken = fakeDeps({ fetch: () => { throw new Error('network'); } });

  assertEquals((await confirm('Bearer emp', down.deps)).status, 502);
  assertEquals((await confirm('Bearer emp', broken.deps)).status, 502);
  assertEquals(down.calls.attached.length + broken.calls.attached.length, 0);
});

Deno.test('confirm: someone else cannot confirm, and a lost race is a 409', async () => {
  const other = fakeDeps({ fetch: () => asset() });
  const raced = fakeDeps({ fetch: () => asset(), attach: false });

  assertEquals((await confirm('Bearer emp2', other.deps)).status, 404);
  assertEquals((await confirm('Bearer emp', raced.deps)).status, 409);
});

// -----------------------------------------------------------------------------
// view (the admin's proxy)
// -----------------------------------------------------------------------------

const photoVisit = () => [visit({ photo_public_id: PUBLIC_ID })];

const imageResponse = (headers: Record<string, string> = {}) =>
  new Response(new Uint8Array([1, 2, 3, 4]), {
    status: 200,
    headers: { 'content-type': 'image/jpeg', 'content-length': '4', ...headers },
  });

Deno.test('view: only an admin sees a photo', async () => {
  const { deps, calls } = fakeDeps({ visits: photoVisit(), fetch: () => imageResponse() });

  const none = await handler(get(`visit_id=${VISIT}`), deps);
  const garbage = await handler(get(`visit_id=${VISIT}`, { Authorization: 'Bearer garbage' }), deps);
  const employee = await handler(get(`visit_id=${VISIT}`, { Authorization: 'Bearer emp' }), deps);

  assertEquals([none.status, garbage.status, employee.status], [401, 401, 403]);
  assertEquals(calls.fetched.length, 0);
});

Deno.test('view: the admin gets the picture, kept private, and no Cloudinary address', async () => {
  const { deps, calls } = fakeDeps({ visits: photoVisit(), fetch: () => imageResponse() });

  const response = await handler(get(`visit_id=${VISIT}&size=thumb`, { Authorization: 'Bearer admin' }), deps);

  assertEquals(response.status, 200);
  assertEquals(response.headers.get('content-type'), 'image/jpeg');
  assertEquals(response.headers.get('cache-control'), 'private, max-age=3600');
  assertEquals(response.headers.get('x-content-type-options'), 'nosniff');
  assertEquals(new Uint8Array(await response.arrayBuffer()), new Uint8Array([1, 2, 3, 4]));
  assertMatch(
    calls.fetched[0].url,
    new RegExp(`^https://res\\.cloudinary\\.com/demo/image/authenticated/s--[A-Za-z0-9_-]{8}--/${THUMB_TRANSFORMATION}/${PUBLIC_ID}$`),
  );
  assertEquals(response.headers.get('location'), null);
});

Deno.test('view: the full size is the original, with its own signature', async () => {
  const { deps, calls } = fakeDeps({ visits: photoVisit(), fetch: () => imageResponse() });

  await handler(get(`visit_id=${VISIT}&size=full`, { Authorization: 'Bearer admin' }), deps);

  assertMatch(calls.fetched[0].url, new RegExp(`/s--[A-Za-z0-9_-]{8}--/${PUBLIC_ID}$`));
  assertEquals(calls.fetched[0].url.includes(THUMB_TRANSFORMATION), false);
});

Deno.test('view: bad parameters, no visit, no photo, a removed photo', async () => {
  const auth = { Authorization: 'Bearer admin' };
  const noPhoto = fakeDeps({ visits: [visit()] });
  const removed = fakeDeps({ visits: [visit({ photo_removed_at: '2026-10-01T00:00:00Z' })] });

  const badSize = await handler(get(`visit_id=${VISIT}&size=huge`, auth), noPhoto.deps);
  const badId = await handler(get('visit_id=nope', auth), noPhoto.deps);
  const missing = await handler(get(`visit_id=${OTHER_VISIT}`, auth), noPhoto.deps);
  const none = await handler(get(`visit_id=${VISIT}`, auth), noPhoto.deps);
  const gone = await handler(get(`visit_id=${VISIT}`, auth), removed.deps);

  assertEquals([badSize.status, badId.status, missing.status], [400, 400, 404]);
  assertEquals([none.status, (await json(none)).error], [404, 'no_photo']);
  assertEquals([gone.status, (await json(gone)).error], [404, 'photo_removed']);
});

Deno.test('view: Cloudinary problems are reported, never passed through', async () => {
  const auth = { Authorization: 'Bearer admin' };
  const run = async (fetchResult: () => Response) => {
    const { deps } = fakeDeps({ visits: photoVisit(), fetch: fetchResult });
    return await handler(get(`visit_id=${VISIT}`, auth), deps);
  };

  assertEquals((await run(() => new Response('', { status: 404 }))).status, 404);
  assertEquals((await run(() => new Response('', { status: 401 }))).status, 404);
  assertEquals((await run(() => new Response('', { status: 500 }))).status, 502);
  assertEquals((await run(() => new Response('<html>', { status: 200, headers: { 'content-type': 'text/html' } }))).status, 502);
  assertEquals((await run(() => imageResponse({ 'content-length': '9000000' }))).status, 502);
  const down = fakeDeps({ visits: photoVisit(), fetch: () => { throw new Error('network'); } });
  assertEquals((await handler(get(`visit_id=${VISIT}`, auth), down.deps)).status, 502);
});

Deno.test('view: a stored photo id that this code did not make is never used', async () => {
  const { deps, calls } = fakeDeps({
    visits: [visit({ photo_public_id: '../../etc/passwd' })],
    fetch: () => imageResponse(),
  });

  const response = await handler(get(`visit_id=${VISIT}`, { Authorization: 'Bearer admin' }), deps);

  assertEquals(response.status, 500);
  assertEquals(calls.fetched.length, 0);
});

// -----------------------------------------------------------------------------
// purge (the nightly 90-day deletion)
// -----------------------------------------------------------------------------

const purge = (deps: Deps, token?: string) =>
  handler(post({ action: 'purge' }, token === undefined ? {} : { 'x-purge-token': token }), deps);

const due = (n: number): DuePhoto[] =>
  Array.from({ length: n }, (_, i) => ({
    id: `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
    photo_public_id: `visit-00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
  }));

Deno.test('purge: it needs the secret token, and an unset token never means anyone', async () => {
  const set = fakeDeps({ due: due(1), fetch: () => new Response('{"result":"ok"}') });
  const unset = fakeDeps({ purgeToken: null, due: due(1) });
  const empty = fakeDeps({ purgeToken: '', due: due(1) });

  assertEquals((await purge(set.deps)).status, 401);
  assertEquals((await purge(set.deps, 'wrong')).status, 401);
  assertEquals((await purge(unset.deps, '')).status, 500);
  assertEquals((await purge(empty.deps, '')).status, 500);
  assertEquals(set.calls.fetched.length + set.calls.removed.length, 0);
});

Deno.test('purge: a user session is not the token', async () => {
  const { deps, calls } = fakeDeps({ due: due(1) });

  const response = await handler(post({ action: 'purge' }, { Authorization: 'Bearer admin' }), deps);

  assertEquals(response.status, 401);
  assertEquals(calls.dueArgs.length, 0);
});

Deno.test('purge: photos older than 90 days are deleted and the visits marked', async () => {
  const { deps, calls } = fakeDeps({
    due: due(2),
    fetch: () => new Response('{"result":"ok"}', { status: 200 }),
  });

  const response = await purge(deps, 'nightly');

  assertEquals(await json(response), { removed: 2, failed: 0, more: false });
  const [cutoff, limit] = calls.dueArgs[0];
  assertEquals(cutoff.toISOString(), '2026-07-20T10:00:00.000Z'); // 90 days before NOW
  assertEquals(limit, 100);
  assertEquals(calls.removed.length, 2);
  assertEquals(calls.audits.length, 1);
  assertEquals(calls.audits[0][0], 'visit_photos_purged');
  assertEquals(calls.audits[0][1].removed, 2);
});

Deno.test('purge: each delete is signed, authenticated and invalidates', async () => {
  const { deps, calls } = fakeDeps({
    due: due(1),
    fetch: () => new Response('{"result":"ok"}'),
  });

  await purge(deps, 'nightly');

  const call = calls.fetched[0];
  assertEquals(call.url, 'https://api.cloudinary.com/v1_1/demo/image/destroy');
  const form = call.init?.body as URLSearchParams;
  assertEquals(form.get('type'), 'authenticated');
  assertEquals(form.get('invalidate'), 'true');
  assertEquals(form.get('public_id'), due(1)[0].photo_public_id);
  assertEquals(form.get('api_key'), 'key');
  assertEquals(
    form.get('signature'),
    await signParams(
      { invalidate: 'true', public_id: due(1)[0].photo_public_id, timestamp: form.get('timestamp') ?? '', type: 'authenticated' },
      'secret',
    ),
  );
  assertEquals(form.has('api_secret'), false);
});

Deno.test('purge: "not found" counts as deleted (it is already gone)', async () => {
  const { deps, calls } = fakeDeps({ due: due(1), fetch: () => new Response('{"result":"not found"}') });

  const response = await purge(deps, 'nightly');

  assertEquals((await json(response)).removed, 1);
  assertEquals(calls.removed.length, 1);
});

Deno.test('purge: a failed delete is not marked, is counted, and is tried again tomorrow', async () => {
  const rejected = fakeDeps({ due: due(1), fetch: () => new Response('{"error":{"message":"x"}}', { status: 401 }) });
  const broken = fakeDeps({ due: due(1), fetch: () => { throw new Error('network'); } });
  const odd = fakeDeps({ due: due(1), fetch: () => new Response('{"result":"weird"}') });

  for (const run of [rejected, broken, odd]) {
    const response = await purge(run.deps, 'nightly');
    assertEquals(await json(response), { removed: 0, failed: 1, more: false });
    assertEquals(run.calls.removed.length, 0);
    assertEquals(run.calls.audits[0][1].failed, 1);
  }
});

Deno.test('purge: one failure does not stop the rest', async () => {
  let n = 0;
  const { deps, calls } = fakeDeps({
    due: due(3),
    fetch: () => (++n === 2 ? new Response('', { status: 500 }) : new Response('{"result":"ok"}')),
  });

  const response = await purge(deps, 'nightly');

  assertEquals(await json(response), { removed: 2, failed: 1, more: false });
  assertEquals(calls.removed.length, 2);
});

Deno.test('purge: nothing due writes no audit entry, and a full batch says there is more', async () => {
  const quiet = fakeDeps({ due: [] });
  const busy = fakeDeps({ due: due(100), fetch: () => new Response('{"result":"ok"}') });

  const none = await purge(quiet.deps, 'nightly');
  const full = await purge(busy.deps, 'nightly');

  assertEquals(await json(none), { removed: 0, failed: 0, more: false });
  assertEquals(quiet.calls.audits.length, 0);
  assertEquals((await json(full)).more, true);
  assertNotEquals(busy.calls.audits.length, 0);
});
