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
