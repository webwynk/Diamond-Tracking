import { assert, assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import { fcmBody, fcmSender, parseServiceAccount, type PushMessage, type Sender } from './fcm.ts';
import { handler } from './handler.ts';

class FakeSender implements Sender {
  sent: { token: string; m: PushMessage }[] = [];
  gone = new Set<string>();
  send(token: string, m: PushMessage) {
    if (this.gone.has(token)) return Promise.resolve('gone' as const);
    this.sent.push({ token, m });
    return Promise.resolve('sent' as const);
  }
}

function job(tokens: string[]) {
  return {
    title: 'Leave request',
    body: 'Asha asked for 2 days',
    kind: 'leave_request',
    data: { request_id: 9, notification_id: 3 },
    tokens,
  };
}

Deno.test('sends to every phone once, data as strings', async () => {
  const b = new FakeBackend();
  b.pushJobs.set(3, job(['t1', 't2']));
  const s = new FakeSender();
  const res = await handler(post({ id: 3 }), b, s);
  assertEquals(await res.json(), { sent: 2, dropped: 0 });
  assertEquals(s.sent[0].m.data, { request_id: '9', notification_id: '3', kind: 'leave_request' });
  // A second call finds nothing to send.
  assertEquals(await (await handler(post({ id: 3 }), b, s)).json(), { sent: 0, dropped: 0 });
  assertEquals(s.sent.length, 2);
});

Deno.test('drops tokens Firebase no longer knows', async () => {
  const b = new FakeBackend();
  b.pushJobs.set(3, job(['t1', 'old']));
  const s = new FakeSender();
  s.gone.add('old');
  assertEquals(await (await handler(post({ id: 3 }), b, s)).json(), { sent: 1, dropped: 1 });
  assertEquals(b.droppedTokens, ['old']);
});

Deno.test('without Firebase nothing is claimed', async () => {
  const b = new FakeBackend();
  b.pushJobs.set(3, job(['t1']));
  assertEquals((await handler(post({ id: 3 }), b, null)).status, 200);
  assert(b.pushJobs.has(3));
  assertEquals((await handler(post({ id: 'x' }), b, null)).status, 400);
});

Deno.test('service account parsing and the FCM body', () => {
  assertEquals(parseServiceAccount(undefined), null);
  assertEquals(parseServiceAccount('{"project_id":"p"}'), null);
  assertEquals(parseServiceAccount('not json'), null);
  const body = fcmBody('tok', { title: 'T', body: null, data: { a: '1' } });
  assertEquals(body.message.notification, { title: 'T' });
  assertEquals(body.message.android.notification.channel_id, 'requests');
});

Deno.test('signs a JWT, caches the access token, reports gone tokens', async () => {
  const { privateKey } = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...der))
  }\n-----END PRIVATE KEY-----\n`;
  const sa = { project_id: 'proj', client_email: 'x@proj.iam', private_key: pem };
  const calls: string[] = [];
  const fetcher = (url: string | URL | Request, init?: RequestInit) => {
    const u = String(url);
    calls.push(u);
    if (u.includes('oauth2')) {
      assert(String(init?.body).includes('assertion='));
      return Promise.resolve(Response.json({ access_token: 'AT', expires_in: 3600 }));
    }
    assertEquals((init?.headers as Record<string, string>).authorization, 'Bearer AT');
    if (JSON.parse(String(init?.body)).message.token === 'dead') {
      return Promise.resolve(
        Response.json(
          { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } },
          {
            status: 404,
          },
        ),
      );
    }
    return Promise.resolve(Response.json({ name: 'ok' }));
  };
  const sender = fcmSender(sa, fetcher as typeof fetch, () => 1_700_000_000_000);
  const m = { title: 'T', body: 'B', data: {} };
  assertEquals(await sender.send('live', m), 'sent');
  assertEquals(await sender.send('dead', m), 'gone');
  assertEquals(calls.filter((c) => c.includes('oauth2')).length, 1);
  assertEquals(calls[1], 'https://fcm.googleapis.com/v1/projects/proj/messages:send');
});

Deno.test('one phone failing does not lose the push for the others (L64, L67)', async () => {
  const b = new FakeBackend();
  b.pushJobs.set(3, job(['t1', 'broken', 'old']));
  const s = new FakeSender();
  s.gone.add('old');
  const flaky: Sender = {
    send: (token, m) =>
      token === 'broken' ? Promise.reject(new Error('network down')) : s.send(token, m),
  };
  const res = await handler(post({ id: 3 }), b, flaky);
  assertEquals(await res.json(), { sent: 1, dropped: 1 });
  assertEquals(s.sent.map((x) => x.token), ['t1']);
  assertEquals(b.droppedTokens, ['old']);
});
