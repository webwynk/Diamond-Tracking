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
  designation: '  Field Assistant ',
  temp_pin: '482915',
};

Deno.test('an admin still on a temporary PIN is refused (L39)', async () => {
  const { b, adminId } = setup();
  b.meta.set(adminId, { role: 'admin', must_change_password: true });
  const res = await handler(post(create, 'admin-token'), b);
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error, 'must_change_password');
});

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
  assertEquals(profile.designation, 'Field Assistant');
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

Deno.test('a new employee needs a designation; an admin may leave it out', async () => {
  const { b } = setup();
  const none = { ...create, designation: '' };
  const refused = await handler(post(none, 'admin-token'), b);
  assertEquals(refused.status, 400);
  assertEquals(Object.keys((await refused.json()).fields), ['designation']);

  const bad = await handler(post({ ...create, designation: 'Sales <b>' }, 'admin-token'), b);
  assertEquals(bad.status, 400);
  assertEquals(Object.keys((await bad.json()).fields), ['designation']);

  const admin = await handler(post({ ...none, role: 'admin' }, 'admin-token'), b);
  assertEquals(admin.status, 201);
  assertEquals((await admin.json()).profile.designation, null);
});

Deno.test('a designation can be set, changed and cleared, and the log shows it', async () => {
  const { b, empId } = setup();
  const set = (designation: string) =>
    handler(post({ action: 'update', id: empId, designation }, 'admin-token'), b);

  assertEquals((await set(' Sales Officer ')).status, 200);
  assertEquals(b.profiles.get(empId)!.designation, 'Sales Officer');
  assertEquals(b.logDetails.at(-1), {
    changes: { designation: { from: null, to: 'Sales Officer' } },
  });

  const bad = await set('x');
  assertEquals(bad.status, 400);
  assertEquals(Object.keys((await bad.json()).fields), ['designation']);
  assertEquals(b.profiles.get(empId)!.designation, 'Sales Officer');

  assertEquals((await set('')).status, 200);
  assertEquals(b.profiles.get(empId)!.designation, null);
  assertEquals(b.logDetails.at(-1), {
    changes: { designation: { from: 'Sales Officer', to: null } },
  });
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

Deno.test('a failed clean-up keeps the first error (L29)', async () => {
  const { b } = setup();
  b.failInsert = true;
  b.failNext.add('deleteAuthUser');
  let message = '';
  try {
    await handler(post(create, 'admin-token'), b);
  } catch (e) {
    message = e instanceof Error ? e.message : '';
  }
  // The profile insert's error, not the clean-up's.
  assertEquals(message, 'db down');
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

Deno.test('the log shows each real change as before and after (L40)', async () => {
  const { b, adminId, empId } = setup();
  const before = b.profiles.get(empId)!;
  // The app sends every field; only the phone and active really change.
  const res = await handler(
    post(
      {
        action: 'update',
        id: empId,
        full_name: before.full_name,
        phone: '9123456780',
        contact_email: before.contact_email ?? '',
        role: before.role,
        is_active: false,
      },
      'admin-token',
    ),
    b,
  );
  assertEquals(res.status, 200);
  assertEquals(b.log.at(-1), { admin: adminId, action: 'update_user', target: empId });
  assertEquals(b.logDetails.at(-1), {
    changes: {
      phone: { from: before.phone, to: '9123456780' },
      is_active: { from: true, to: false },
    },
  });
  // Turning back on reads differently from turning off.
  await handler(post({ action: 'update', id: empId, is_active: true }, 'admin-token'), b);
  assertEquals(b.logDetails.at(-1), { changes: { is_active: { from: false, to: true } } });
});

Deno.test('saving with nothing changed writes and logs nothing (L40)', async () => {
  const { b, empId } = setup();
  const p = b.profiles.get(empId)!;
  const res = await handler(
    post({ action: 'update', id: empId, full_name: p.full_name, role: p.role }, 'admin-token'),
    b,
  );
  assertEquals(res.status, 200);
  assertEquals(b.log, []);
  assertEquals(b.revoked, []);
});

Deno.test('a failed role save puts the sign-in role back (L41)', async () => {
  const { b, empId } = setup();
  b.meta.set(empId, { role: 'employee' });
  b.failNext.add('updateProfile');
  let threw = false;
  try {
    await handler(post({ action: 'update', id: empId, role: 'admin' }, 'admin-token'), b);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
  assertEquals(b.profiles.get(empId)!.role, 'employee');
  assertEquals(b.meta.get(empId)!.role, 'employee');
  assertEquals(b.log, []);
});

Deno.test('a failed sign-in role save leaves the profile alone (L41)', async () => {
  const { b, empId } = setup();
  b.meta.set(empId, { role: 'employee' });
  b.failNext.add('mergeAppMetadata');
  let threw = false;
  try {
    await handler(post({ action: 'update', id: empId, role: 'admin' }, 'admin-token'), b);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
  assertEquals(b.profiles.get(empId)!.role, 'employee');
  assertEquals(b.meta.get(empId)!.role, 'employee');
});

Deno.test('reset PIN: a PIN never works without "must change" (L42, L30)', async () => {
  const { b, empId } = setup();
  b.meta.set(empId, { role: 'employee', must_change_password: false });
  b.passwords.set(empId, 'old-password');
  b.failNext.add('setPassword');
  let threw = false;
  try {
    await handler(post({ action: 'reset_pin', id: empId, temp_pin: '305127' }, 'admin-token'), b);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
  // The password step failed: the old password still works, and the user
  // is asked to choose a new one at the next sign-in. Never the PIN alone.
  assertEquals(b.passwords.get(empId), 'old-password');
  assertEquals(b.meta.get(empId)!.must_change_password, true);
});

Deno.test('reset PIN: a failed sign-out says the PIN is set (L42)', async () => {
  const { b, empId } = setup();
  b.failNext.add('revokeSessions');
  const res = await handler(
    post({ action: 'reset_pin', id: empId, temp_pin: '305127' }, 'admin-token'),
    b,
  );
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, 'reset_incomplete');
  assertEquals(b.passwords.get(empId), '305127');
  assertEquals(b.meta.get(empId)!.must_change_password, true);
  // Pressing Reset again finishes it.
  const again = await handler(
    post({ action: 'reset_pin', id: empId, temp_pin: '305127' }, 'admin-token'),
    b,
  );
  assertEquals(again.status, 200);
  assertEquals(b.revoked, [empId]);
});
