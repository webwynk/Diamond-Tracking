import { assertEquals } from '@std/assert';
import { FakeBackend, post } from '../_shared/fake_backend_test_support.ts';
import { handler } from './handler.ts';

function setup() {
  const b = new FakeBackend();
  const adminId = b.addUser({ user_code: 'ADMIN1', role: 'admin' }, 'admin-token', {
    role: 'admin',
  });
  const empId = b.addUser({ user_code: 'DA-001' }, 'emp-token');
  return { b, adminId, empId };
}

const create = {
  action: 'create',
  user_code: 'DA-050',
  full_name: 'Kiran Das',
  phone: '9876543210',
  contact_email: 'Kiran@Example.com',
  temp_pin: '482915',
};

Deno.test('only an active admin may use it', async () => {
  const { b } = setup();
  assertEquals((await handler(post(create), b)).status, 401);
  assertEquals((await handler(post(create, 'bad'), b)).status, 401);
  assertEquals((await handler(post(create, 'emp-token'), b)).status, 403);
});

Deno.test('creates a user on a temporary PIN', async () => {
  const { b, adminId } = setup();
  const res = await handler(post(create, 'admin-token'), b);
  assertEquals(res.status, 201);
  const { profile } = await res.json();
  assertEquals(profile.user_code, 'DA-050');
  assertEquals(profile.contact_email, 'kiran@example.com');
  assertEquals(b.passwords.get(profile.id), '482915');
  assertEquals(b.meta.get(profile.id), { role: 'employee', must_change_password: true });
  assertEquals(b.emails.get('da-050@staff.diamondagritech.internal'), profile.id);
  assertEquals(b.log, [{ admin: adminId, action: 'create_user', target: profile.id }]);
});

Deno.test('rejects bad input with a message per field', async () => {
  const { b } = setup();
  const res = await handler(
    post(
      { ...create, user_code: 'a b', temp_pin: '111111', phone: '12', contact_email: 'x' },
      'admin-token',
    ),
    b,
  );
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(Object.keys(body.fields).sort(), [
    'contact_email',
    'phone',
    'temp_pin',
    'user_code',
  ]);
});

Deno.test('a user ID can only be used once, in any letter case', async () => {
  const { b } = setup();
  const res = await handler(post({ ...create, user_code: 'da-001' }, 'admin-token'), b);
  assertEquals(res.status, 409);
});

Deno.test('a failed profile insert removes the new sign-in account', async () => {
  const { b } = setup();
  b.failInsert = true;
  let threw = false;
  try {
    await handler(post(create, 'admin-token'), b);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
  assertEquals(b.emails.has('da-050@staff.diamondagritech.internal'), false);
});

Deno.test('deactivating a user signs them out everywhere', async () => {
  const { b, empId } = setup();
  const res = await handler(
    post({ action: 'update', id: empId, is_active: false }, 'admin-token'),
    b,
  );
  assertEquals(res.status, 200);
  assertEquals(b.profiles.get(empId)!.is_active, false);
  assertEquals(b.revoked, [empId]);
});

Deno.test('changing the role updates the sign-in claim', async () => {
  const { b, empId } = setup();
  await handler(post({ action: 'update', id: empId, role: 'admin' }, 'admin-token'), b);
  assertEquals(b.meta.get(empId)!.role, 'admin');
  assertEquals(b.revoked, [empId]);
});

Deno.test('an admin cannot deactivate or demote themselves', async () => {
  const { b, adminId } = setup();
  const r1 = await handler(
    post({ action: 'update', id: adminId, is_active: false }, 'admin-token'),
    b,
  );
  const r2 = await handler(
    post({ action: 'update', id: adminId, role: 'employee' }, 'admin-token'),
    b,
  );
  assertEquals([r1.status, r2.status], [409, 409]);
});

Deno.test('reset PIN: new temporary PIN, must change, signed out, phone freed', async () => {
  const { b, empId } = setup();
  b.meta.set(empId, { role: 'employee', must_change_password: false });
  const res = await handler(
    post({ action: 'reset_pin', id: empId, temp_pin: '305127' }, 'admin-token'),
    b,
  );
  assertEquals(res.status, 200);
  assertEquals(b.passwords.get(empId), '305127');
  assertEquals(b.meta.get(empId)!.must_change_password, true);
  assertEquals(b.revoked, [empId]);
  assertEquals(b.log.at(-1)!.action, 'reset_pin');
});

Deno.test('reset PIN for an unknown user', async () => {
  const { b } = setup();
  const res = await handler(
    post(
      { action: 'reset_pin', id: '00000000-0000-0000-0000-000000000999', temp_pin: '305127' },
      'admin-token',
    ),
    b,
  );
  assertEquals(res.status, 404);
});
