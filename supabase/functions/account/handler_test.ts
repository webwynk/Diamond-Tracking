import { assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import { handler } from './handler.ts';

Deno.test('sets the first password and clears the flag', async () => {
  const b = new FakeBackend();
  const id = b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: true });
  const res = await handler(post({ action: 'set_password', new_password: 'fields2026' }, 't'), b);
  assertEquals(res.status, 200);
  assertEquals(b.passwords.get(id), 'fields2026');
  assertEquals(b.meta.get(id)!.must_change_password, false);
});

Deno.test('only while on a temporary PIN', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: false });
  const res = await handler(post({ action: 'set_password', new_password: 'fields2026' }, 't'), b);
  assertEquals(res.status, 403);
});

Deno.test('weak passwords are refused', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001' }, 't', { must_change_password: true });
  for (const pw of ['short1', 'onlyletters', '12345678', 'da-001abc9']) {
    const res = await handler(post({ action: 'set_password', new_password: pw }, 't'), b);
    assertEquals(res.status, 400, pw);
  }
});

Deno.test('needs a signed-in, active user', async () => {
  const b = new FakeBackend();
  b.addUser({ user_code: 'DA-001', is_active: false }, 't', { must_change_password: true });
  assertEquals(
    (await handler(post({ action: 'set_password', new_password: 'fields2026' }), b)).status,
    401,
  );
  assertEquals(
    (await handler(post({ action: 'set_password', new_password: 'fields2026' }, 't'), b)).status,
    403,
  );
});
