import { assertEquals } from '@std/assert';
import { FakeBackend, FakeMailer, post } from '../_shared/fake_backend_test_support.ts';
import { handler, randomCode } from './handler.ts';

function setup() {
  const b = new FakeBackend();
  const id = b.addUser({ user_code: 'DA-001', contact_email: 'kiran@example.com' }, undefined, {
    must_change_password: true,
  });
  b.addUser({ user_code: 'DA-002' }); // no email
  return { b, id, mail: new FakeMailer() };
}

Deno.test('emails a code to the contact address', async () => {
  const { b, id, mail } = setup();
  const res = await handler(
    post({ action: 'request', user_code: 'da-001' }),
    b,
    mail,
    () => '123456',
  );
  assertEquals(res.status, 200);
  assertEquals(mail.sent.length, 1);
  assertEquals(mail.sent[0].to, 'kiran@example.com');
  assertEquals(mail.sent[0].text.includes('123456'), true);
  assertEquals(b.codes.get(id), '123456');
});

Deno.test('the same answer for unknown users and users without email', async () => {
  const { b, mail } = setup();
  const r1 = await handler(post({ action: 'request', user_code: 'NOPE' }), b, mail);
  const r2 = await handler(post({ action: 'request', user_code: 'DA-002' }), b, mail);
  assertEquals([r1.status, r2.status], [200, 200]);
  assertEquals(await r1.json(), await r2.json());
  assertEquals(mail.sent.length, 0);
});

Deno.test('over 5 codes today: no email, and the same answer (M7)', async () => {
  const { b, mail } = setup();
  b.resetCodeLimit = 'user';
  const res = await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ok: true });
  assertEquals(mail.sent.length, 0);
});

Deno.test("today's reset emails used up: says so (M7)", async () => {
  const { b, mail } = setup();
  b.resetCodeLimit = 'daily';
  const res = await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail);
  assertEquals(res.status, 429);
  assertEquals(await res.json(), { error: 'daily_email_limit' });
  assertEquals(mail.sent.length, 0);
});

Deno.test('says so when no email service is set up', async () => {
  const { b } = setup();
  const res = await handler(
    post({ action: 'request', user_code: 'DA-001' }),
    b,
    new FakeMailer(false),
  );
  assertEquals(res.status, 503);
});

Deno.test('a right code sets the password and signs out everywhere', async () => {
  const { b, id, mail } = setup();
  await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail, () => '654321');
  const res = await handler(
    post({ action: 'confirm', user_code: 'DA-001', code: '654321', new_password: 'newpass2026' }),
    b,
    mail,
  );
  assertEquals(res.status, 200);
  assertEquals(b.passwords.get(id), 'newpass2026');
  assertEquals(b.meta.get(id)!.must_change_password, false);
  assertEquals(b.revoked, [id]);
});

Deno.test('a wrong code changes nothing', async () => {
  const { b, id, mail } = setup();
  await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail, () => '654321');
  const res = await handler(
    post({ action: 'confirm', user_code: 'DA-001', code: '000000', new_password: 'newpass2026' }),
    b,
    mail,
  );
  assertEquals(res.status, 400);
  assertEquals(b.passwords.has(id), false);
});

Deno.test('codes are 6 digits', () => {
  for (let i = 0; i < 50; i++) assertEquals(/^[0-9]{6}$/.test(randomCode()), true);
});

Deno.test('a wrong code gets the same answer for real and unknown IDs (L60)', async () => {
  const { b, mail } = setup();
  await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail, () => '654321');
  const answers = [];
  for (const user_code of ['DA-001', 'DA-002', 'DA-999']) {
    const res = await handler(
      post({ action: 'confirm', user_code, code: '000000', new_password: 'weak' }),
      b,
      mail,
    );
    answers.push([res.status, (await res.json()).error]);
  }
  assertEquals(answers, [
    [400, 'invalid_code'],
    [400, 'invalid_code'],
    [400, 'invalid_code'],
  ]);
});

Deno.test('the right code with a weak password names the password rule (L60)', async () => {
  const { b, id, mail } = setup();
  await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail, () => '654321');
  const res = await handler(
    post({ action: 'confirm', user_code: 'DA-001', code: '654321', new_password: 'weak' }),
    b,
    mail,
  );
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, 'validation_failed');
  assertEquals(b.passwords.has(id), false);
});

Deno.test('a turned-off user cannot use a code (L67)', async () => {
  const { b, id, mail } = setup();
  await handler(post({ action: 'request', user_code: 'DA-001' }), b, mail, () => '654321');
  b.profiles.set(id, { ...b.profiles.get(id)!, is_active: false });
  const res = await handler(
    post({ action: 'confirm', user_code: 'DA-001', code: '654321', new_password: 'newpass2026' }),
    b,
    mail,
  );
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, 'invalid_code');
  assertEquals(b.passwords.has(id), false);
});
