import { assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import { PASSWORD_TOO_LONG } from '../_shared/rules.ts';
import { handler } from './handler.ts';

Deno.test('sets the first password and clears the flag', async () => {
  const b = new FakeBackend();
  const id = b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: true });
  const res = await handler(post({ action: 'set_password', new_password: 'fields@2026' }, 't'), b);
  assertEquals(res.status, 200);
  assertEquals(b.passwords.get(id), 'fields@2026');
  assertEquals(b.meta.get(id)!.must_change_password, false);
});

Deno.test('only while on a temporary PIN', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: false });
  const res = await handler(post({ action: 'set_password', new_password: 'fields@2026' }, 't'), b);
  assertEquals(res.status, 403);
});

Deno.test('weak passwords are refused', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: true });
  // '482913': a 6-digit PIN is refused by the password rules themselves.
  for (
    const pw of [
      'short1',
      'onlyletters',
      '12345678',
      'da-001abc9!',
      '482913',
      'fields2026',
      'Mango@2025',
    ]
  ) {
    const res = await handler(post({ action: 'set_password', new_password: pw }, 't'), b);
    assertEquals(res.status, 400, pw);
  }
});

Deno.test('needs a signed-in, active user', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001', is_active: false }, 't', { must_change_password: true });
  assertEquals(
    (await handler(post({ action: 'set_password', new_password: 'fields@2026' }), b)).status,
    401,
  );
  assertEquals(
    (await handler(post({ action: 'set_password', new_password: 'fields@2026' }, 't'), b)).status,
    403,
  );
});

Deno.test('a password over 72 bytes is refused with a clear message (L36)', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: true });
  // 30 Hindi letters (3 bytes each) + "ab12": 34 characters, 94 bytes.
  const pw = `${'क'.repeat(30)}ab12`;
  const res = await handler(post({ action: 'set_password', new_password: pw }, 't'), b);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).fields.new_password, PASSWORD_TOO_LONG);
});
