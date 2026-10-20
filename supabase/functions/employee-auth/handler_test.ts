// deno test supabase/functions/employee-auth
import { assertEquals } from 'jsr:@std/assert@1';
import type { Deps, LoginCheck, PinResult, ProfileRow, Session } from './deps.ts';
import { handler } from './handler.ts';

const EMPLOYEE = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const ADMIN = '33333333-3333-4333-8333-333333333333';

const SESSION: Session = {
  access_token: 'access',
  refresh_token: 'refresh',
  expires_in: 3600,
  expires_at: 1_800_000_000,
  token_type: 'bearer',
};

type Calls = {
  loginCheck: Array<[string, string]>;
  signIn: Array<[string, string]>;
  setPin: Array<[string, string, boolean]>;
  adminResetPin: Array<[string, string, string]>;
};

function fakeDeps(opts: {
  check?: LoginCheck;
  checkThrows?: boolean;
  signInResult?: Session | null;
  tokens?: Record<string, string>;
  admins?: string[];
  profiles?: Record<string, ProfileRow>;
  pinResult?: PinResult;
} = {}): { deps: Deps; calls: Calls } {
  const calls: Calls = { loginCheck: [], signIn: [], setPin: [], adminResetPin: [] };
  const tokens = opts.tokens ?? { 'Bearer emp': EMPLOYEE, 'Bearer adm': ADMIN };
  const profiles = opts.profiles ?? {
    [EMPLOYEE]: { id: EMPLOYEE, role: 'employee', status: 'active', must_change_pin: true },
    [OTHER]: { id: OTHER, role: 'employee', status: 'active', must_change_pin: false },
    [ADMIN]: { id: ADMIN, role: 'admin', status: 'active', must_change_pin: false },
  };
  const deps: Deps = {
    loginCheck(code, pin) {
      calls.loginCheck.push([code, pin]);
      if (opts.checkThrows) return Promise.reject(new Error('db down'));
      return Promise.resolve(opts.check ?? { result: 'invalid' });
    },
    signIn(email, password) {
      calls.signIn.push([email, password]);
      return Promise.resolve(opts.signInResult === undefined ? SESSION : opts.signInResult);
    },
    userId: (auth) => Promise.resolve(tokens[auth] ?? null),
    isAdmin: (auth) => Promise.resolve((opts.admins ?? [ADMIN]).includes(tokens[auth] ?? '')),
    profileOf: (id) => Promise.resolve(profiles[id] ?? null),
    setPin(userId, pin, mustChange) {
      calls.setPin.push([userId, pin, mustChange]);
      return Promise.resolve(opts.pinResult ?? { ok: true });
    },
    adminResetPin(actor, userId, pin) {
      calls.adminResetPin.push([actor, userId, pin]);
      return Promise.resolve(opts.pinResult ?? { ok: true });
    },
  };
  return { deps, calls };
}

function post(body: unknown, auth?: string): Request {
  return new Request('https://x.test/employee-auth', {
    method: 'POST',
    headers: auth ? { Authorization: auth, 'Content-Type': 'application/json' } : {
      'Content-Type': 'application/json',
    },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

const OK_CHECK: LoginCheck = {
  result: 'ok',
  user_id: EMPLOYEE,
  email: 'da-014@staff.diamondagritech.internal',
  login_password: 'derived-secret',
  must_change_pin: true,
};

Deno.test('router: only POST, only known actions, only JSON', async () => {
  const { deps } = fakeDeps();
  assertEquals((await handler(new Request('https://x.test/', { method: 'GET' }), deps)).status, 405);
  assertEquals((await handler(post('not json'), deps)).status, 400);
  assertEquals((await handler(post('null'), deps)).status, 400);
  assertEquals((await handler(post({ action: 'sudo' }), deps)).status, 400);
});

Deno.test('login: the right PIN returns a session and the "must change" flag', async () => {
  const { deps, calls } = fakeDeps({ check: OK_CHECK });
  const res = await handler(post({ action: 'login', employee_code: ' DA-014 ', pin: '482915' }), deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.session.refresh_token, 'refresh');
  assertEquals(body.must_change_pin, true);
  assertEquals(calls.loginCheck, [['DA-014', '482915']]);
  // The server signs in with the derived password, never with the PIN.
  assertEquals(calls.signIn, [['da-014@staff.diamondagritech.internal', 'derived-secret']]);
});

Deno.test('login: a wrong PIN is a plain 401 that says nothing more', async () => {
  const { deps, calls } = fakeDeps({ check: { result: 'invalid' } });
  const res = await handler(post({ action: 'login', employee_code: 'DA-014', pin: '000001' }), deps);
  assertEquals(res.status, 401);
  assertEquals(await res.json(), { error: 'invalid_credentials' });
  assertEquals(calls.signIn.length, 0);
});

Deno.test('login: locked gives 429 and the wait, and never signs in', async () => {
  const { deps, calls } = fakeDeps({ check: { result: 'locked', retry_after_seconds: 600 } });
  const res = await handler(post({ action: 'login', employee_code: 'DA-014', pin: '482915' }), deps);
  assertEquals(res.status, 429);
  assertEquals(await res.json(), { error: 'account_locked', retry_after_seconds: 600 });
  assertEquals(calls.signIn.length, 0);
});

Deno.test('login: blocked gives 403 and never signs in', async () => {
  const { deps, calls } = fakeDeps({ check: { result: 'blocked' } });
  const res = await handler(post({ action: 'login', employee_code: 'DA-014', pin: '482915' }), deps);
  assertEquals(res.status, 403);
  assertEquals(await res.json(), { error: 'account_blocked' });
  assertEquals(calls.signIn.length, 0);
});

Deno.test('login: bad input is refused before the database is asked', async () => {
  const { deps, calls } = fakeDeps({ check: OK_CHECK });
  for (
    const body of [
      { action: 'login' },
      { action: 'login', employee_code: '', pin: '482915' },
      { action: 'login', employee_code: 'DA-014', pin: '' },
      { action: 'login', employee_code: 'DA-014', pin: 482915 },
      { action: 'login', employee_code: 'X'.repeat(21), pin: '482915' },
      { action: 'login', employee_code: 'DA-014', pin: '1'.repeat(13) },
    ]
  ) {
    assertEquals((await handler(post(body), deps)).status, 400);
  }
  assertEquals(calls.loginCheck.length, 0);
});

Deno.test('login: a failing database or a refused sign-in is a 500 with no detail', async () => {
  const down = fakeDeps({ checkThrows: true });
  const r1 = await handler(post({ action: 'login', employee_code: 'DA-014', pin: '482915' }), down.deps);
  assertEquals(r1.status, 500);
  assertEquals(await r1.json(), { error: 'login_failed' });

  const refused = fakeDeps({ check: OK_CHECK, signInResult: null });
  const r2 = await handler(post({ action: 'login', employee_code: 'DA-014', pin: '482915' }), refused.deps);
  assertEquals(r2.status, 500);
  assertEquals(await r2.json(), { error: 'login_failed' });
});

Deno.test('change_pin: needs a session', async () => {
  const { deps, calls } = fakeDeps();
  assertEquals((await handler(post({ action: 'change_pin', new_pin: '135792' }), deps)).status, 401);
  assertEquals(
    (await handler(post({ action: 'change_pin', new_pin: '135792' }, 'Bearer nobody'), deps)).status,
    401,
  );
  assertEquals(calls.setPin.length, 0);
});

Deno.test('change_pin: the first-login change works and clears the flag', async () => {
  const { deps, calls } = fakeDeps();
  const res = await handler(post({ action: 'change_pin', new_pin: '135792' }, 'Bearer emp'), deps);
  assertEquals(res.status, 200);
  assertEquals(calls.setPin, [[EMPLOYEE, '135792', false]]);
});

Deno.test('change_pin: only while "must change" is set; an admin session cannot use it', async () => {
  const { deps, calls } = fakeDeps({
    tokens: { 'Bearer other': OTHER, 'Bearer adm': ADMIN },
  });
  const later = await handler(post({ action: 'change_pin', new_pin: '135792' }, 'Bearer other'), deps);
  assertEquals(later.status, 403);
  assertEquals(await later.json(), { error: 'pin_change_not_allowed' });
  const admin = await handler(post({ action: 'change_pin', new_pin: '135792' }, 'Bearer adm'), deps);
  assertEquals(admin.status, 403);
  assertEquals(calls.setPin.length, 0);
});

Deno.test('change_pin: a refused PIN is a 400 with the reason, nothing else', async () => {
  const { deps } = fakeDeps({ pinResult: { ok: false, problem: 'PIN cannot be a simple sequence like 123456' } });
  const res = await handler(post({ action: 'change_pin', new_pin: '123456' }, 'Bearer emp'), deps);
  assertEquals(res.status, 400);
  assertEquals(await res.json(), {
    error: 'validation_failed',
    fields: { pin: 'PIN cannot be a simple sequence like 123456' },
  });
});

Deno.test('change_pin: a blocked employee is refused', async () => {
  const { deps, calls } = fakeDeps({
    profiles: {
      [EMPLOYEE]: { id: EMPLOYEE, role: 'employee', status: 'blocked', must_change_pin: true },
    },
  });
  const res = await handler(post({ action: 'change_pin', new_pin: '135792' }, 'Bearer emp'), deps);
  assertEquals(res.status, 403);
  assertEquals(calls.setPin.length, 0);
});

Deno.test('reset_pin: only an active admin, only for an employee', async () => {
  const { deps, calls } = fakeDeps();
  const body = { action: 'reset_pin', employee_id: OTHER, new_pin: '246813' };

  assertEquals((await handler(post(body), deps)).status, 401);
  assertEquals((await handler(post(body, 'Bearer nobody'), deps)).status, 401);
  assertEquals((await handler(post(body, 'Bearer emp'), deps)).status, 403);
  assertEquals(calls.adminResetPin.length, 0);

  const ok = await handler(post(body, 'Bearer adm'), deps);
  assertEquals(ok.status, 200);
  assertEquals(calls.adminResetPin, [[ADMIN, OTHER, '246813']]);

  const toAdmin = await handler(
    post({ action: 'reset_pin', employee_id: ADMIN, new_pin: '246813' }, 'Bearer adm'),
    deps,
  );
  assertEquals(toAdmin.status, 404);
  const missing = await handler(
    post({ action: 'reset_pin', employee_id: '99999999-9999-4999-8999-999999999999', new_pin: '246813' }, 'Bearer adm'),
    deps,
  );
  assertEquals(missing.status, 404);
  assertEquals(calls.adminResetPin.length, 1);
});

Deno.test('reset_pin: bad input and a refused PIN', async () => {
  const { deps, calls } = fakeDeps({ pinResult: { ok: false, problem: 'PIN cannot be one repeated digit' } });
  assertEquals(
    (await handler(post({ action: 'reset_pin', employee_id: 'nope', new_pin: '246813' }, 'Bearer adm'), deps)).status,
    400,
  );
  assertEquals(
    (await handler(post({ action: 'reset_pin', employee_id: OTHER }, 'Bearer adm'), deps)).status,
    400,
  );
  assertEquals(calls.adminResetPin.length, 0);

  const refused = await handler(
    post({ action: 'reset_pin', employee_id: OTHER, new_pin: '111111' }, 'Bearer adm'),
    deps,
  );
  assertEquals(refused.status, 400);
  assertEquals((await refused.json()).fields.pin, 'PIN cannot be one repeated digit');
});
