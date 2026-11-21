import { assertEquals } from '@std/assert';
import { resendMailer } from './mailer.ts';

function mailer(fetcher: typeof fetch, timeoutMs = 50) {
  return resendMailer({ key: 'k', from: 'reset@example.com', fetcher, timeoutMs });
}

Deno.test('a sent email returns true', async () => {
  const ok: typeof fetch = () => Promise.resolve(new Response(null, { status: 200 }));
  assertEquals(await mailer(ok).send('a@example.com', 's', 't'), true);
});

Deno.test('Resend refusing the email returns false', async () => {
  const refused: typeof fetch = () => Promise.resolve(new Response('no', { status: 422 }));
  assertEquals(await mailer(refused).send('a@example.com', 's', 't'), false);
});

Deno.test('no internet returns false instead of failing', async () => {
  const down: typeof fetch = () => Promise.reject(new TypeError('network down'));
  assertEquals(await mailer(down).send('a@example.com', 's', 't'), false);
});

Deno.test('a Resend that never answers is given up after the time limit (L34)', async () => {
  const hangs: typeof fetch = (_input, init) =>
    new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => reject(new DOMException('aborted')));
    });
  const started = Date.now();
  assertEquals(await mailer(hangs, 50).send('a@example.com', 's', 't'), false);
  assertEquals(Date.now() - started < 2_000, true);
});

Deno.test('not configured without a key or a sender', () => {
  const ok: typeof fetch = () => Promise.resolve(new Response(null));
  assertEquals(resendMailer({ key: '', from: 'x@example.com', fetcher: ok }).configured, false);
  assertEquals(resendMailer({ key: 'k', from: '', fetcher: ok }).configured, false);
});
