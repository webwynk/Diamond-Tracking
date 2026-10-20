// create-employee — creates an employee login (employee code + 6-digit PIN).
//
// Why this is a server function: creating a login needs the secret key, which
// must never be inside the app (docs/05 section 2). The caller must be a
// signed-in ACTIVE ADMIN, checked here with the public.is_admin() database
// function, never inferred from the fact that the function was called.
//
// Request  (POST, JSON, Authorization: Bearer <admin session token>)
//   { "full_name": "Kiran Deshmukh", "phone": "+919822011334",
//     "employee_code": "DA-144", "pin": "482915",
//     "email": "kiran@example.com" }            // email is optional (contact only)
// Success  201 { "employee": { id, employee_code, full_name, phone, contact_email } }
// Errors   400 validation_failed | 401 unauthenticated | 403 forbidden
//          405 method_not_allowed | 409 employee_code_taken | phone_taken
//          500 create_failed | audit_failed
//
// Never logged: PINs, phone numbers, names.
import { createClient } from 'npm:@supabase/supabase-js@2';

const SYNTHETIC_EMAIL_DOMAIN = 'staff.diamondagritech.internal';

type Json = Record<string, unknown>;

function reply(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * Exactly 6 digits, not one repeated digit, not a run up or down that may wrap
 * round (PRD F1). This is the same rule as private.pin_problem in the database,
 * which is the one that decides; this copy only gives an early, clear message.
 */
export function pinProblem(pin: string): string | null {
  if (!/^\d{6}$/.test(pin)) return 'PIN must be exactly 6 digits';
  if (/^(\d)\1{5}$/.test(pin)) return 'PIN cannot be one repeated digit';
  const d = pin.split('').map(Number);
  const up = d.every((n, i) => i === 0 || n === (d[i - 1] + 1) % 10);
  const down = d.every((n, i) => i === 0 || n === (d[i - 1] + 9) % 10);
  if (up || down) return 'PIN cannot be a simple sequence like 123456';
  return null;
}

export function validate(input: Json): { value?: Parsed; fields?: Record<string, string> } {
  const fields: Record<string, string> = {};
  const fullName = typeof input.full_name === 'string' ? input.full_name.trim() : '';
  const phone = typeof input.phone === 'string' ? input.phone.replace(/[\s-]/g, '') : '';
  const code = typeof input.employee_code === 'string' ? input.employee_code.trim().toUpperCase() : '';
  const pin = typeof input.pin === 'string' ? input.pin : '';
  const email = typeof input.email === 'string' ? input.email.trim().toLowerCase() : '';

  if (fullName.length < 2 || fullName.length > 80) fields.full_name = 'Enter a name of 2 to 80 characters';
  if (!/^\+?\d{10,15}$/.test(phone)) fields.phone = 'Enter a phone number with 10 to 15 digits';
  if (!/^[A-Z]{2,4}-\d{2,6}$/.test(code)) fields.employee_code = 'Use a code like DA-144';
  if (email !== '' && (email.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
    fields.email = 'Enter a valid email address or leave it empty';
  }
  const pinIssue = pinProblem(pin);
  if (pinIssue) fields.pin = pinIssue;

  if (Object.keys(fields).length > 0) return { fields };
  return { value: { fullName, phone, code, pin, email } };
}

type Parsed = { fullName: string; phone: string; code: string; pin: string; email: string };

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) return reply(500, { error: 'create_failed' });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return reply(401, { error: 'unauthenticated' });

  // 1. Who is calling, and are they an active admin? (as THEM, not as the server)
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: who, error: whoError } = await asCaller.auth.getUser();
  if (whoError || !who.user) return reply(401, { error: 'unauthenticated' });

  const { data: isAdmin, error: adminError } = await asCaller.rpc('is_admin');
  if (adminError || isAdmin !== true) return reply(403, { error: 'forbidden' });

  // 2. Validate the input
  let body: Json;
  try {
    body = (await req.json()) as Json;
  } catch {
    return reply(400, { error: 'validation_failed', fields: { body: 'Send a JSON body' } });
  }
  const parsed = validate(body);
  if (!parsed.value) return reply(400, { error: 'validation_failed', fields: parsed.fields });
  const { fullName, phone, code, pin, email } = parsed.value;

  // 3. Only now use the privileged client
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

  const { data: clash, error: clashError } = await admin
    .from('profiles')
    .select('employee_code, phone')
    .or(`employee_code.eq.${code},phone.eq.${phone}`)
    .limit(2);
  if (clashError) return reply(500, { error: 'create_failed' });
  if (clash?.some((r: { employee_code?: string }) => r.employee_code === code)) return reply(409, { error: 'employee_code_taken' });
  if (clash?.some((r: { phone?: string }) => r.phone === phone)) return reply(409, { error: 'phone_taken' });

  // 4. Create the login. Only the role goes into app_metadata (server-only, not
  // editable by the user). The employee's details are NOT passed this way: the
  // auth service saves app_metadata AFTER it inserts the user, so a trigger on
  // auth.users never sees them (found 2026-10-17 on the first real attempt:
  // the account was created and then rolled back because no profile existed).
  const loginEmail = `${code.toLowerCase()}@${SYNTHETIC_EMAIL_DOMAIN}`;
  // The login's real password is a throw-away here: set_employee_pin (step 5b)
  // replaces it with the derived one, and the PIN itself is kept only as a hash.
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: loginEmail,
    password: crypto.randomUUID() + crypto.randomUUID(),
    email_confirm: true,
    app_metadata: { role: 'employee' },
    user_metadata: { full_name: fullName },
  });
  if (createError || !created.user) {
    console.error('createUser failed', createError?.status, createError?.code);
    return reply(500, { error: 'create_failed' });
  }
  const userId = created.user.id;

  // 5. Write the profile here, in the same request. If it cannot be written,
  // undo the login so there is never a login without a profile.
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .insert({
      id: userId,
      email: loginEmail,
      contact_email: email === '' ? null : email,
      role: 'employee',
      status: 'active',
      full_name: fullName,
      employee_code: code,
      phone,
      must_change_pin: true,
    })
    .select('id, employee_code, full_name, phone, contact_email')
    .single();
  if (profileError || !profile) {
    console.error('profile insert failed', profileError?.code);
    await admin.auth.admin.deleteUser(userId);
    if (profileError?.code === '23505') {
      // Someone else took the code or phone between the check above and now.
      const phoneClash = (profileError.message ?? '').includes('phone');
      return reply(409, { error: phoneClash ? 'phone_taken' : 'employee_code_taken' });
    }
    return reply(500, { error: 'create_failed' });
  }

  // 5b. The PIN: stored as a hash, checked by the server at every login, and the
  // login's own password becomes a derived secret. A refused PIN or a failure
  // undoes the whole account.
  const { error: pinError } = await admin.rpc('set_employee_pin', {
    p_user: userId,
    p_pin: pin,
    p_must_change: true,
  });
  if (pinError) {
    console.error('set_employee_pin failed', pinError.code);
    await admin.auth.admin.deleteUser(userId);
    if (pinError.message === 'pin_invalid') {
      return reply(400, {
        error: 'validation_failed',
        fields: { pin: pinError.details ?? 'Choose a different PIN' },
      });
    }
    return reply(500, { error: 'create_failed' });
  }

  // 6. Every admin action is audited (PRD F2). No audit, no account.
  const { error: auditError } = await admin.from('audit_log').insert({
    actor_id: who.user.id,
    action: 'employee_created',
    target_id: userId,
    details: { employee_code: code },
  });
  if (auditError) {
    console.error('audit insert failed', auditError.code);
    // Remove the login; the profile row goes with it (it references the login).
    await admin.auth.admin.deleteUser(userId);
    return reply(500, { error: 'audit_failed' });
  }

  return reply(201, {
    employee: {
      id: profile.id,
      employee_code: profile.employee_code,
      full_name: profile.full_name,
      phone: profile.phone,
      contact_email: profile.contact_email,
    },
  });
});
