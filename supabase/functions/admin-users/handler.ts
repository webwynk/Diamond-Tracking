// admin-users: the admin creates and edits users and resets temporary PINs.
//
//   POST { action: "create", user_code, full_name, phone?, contact_email?,
//          role?: "employee" | "admin", temp_pin }                -> 201 { profile }
//   POST { action: "update", id, full_name?, phone?, contact_email?,
//          role?, is_active? }                                    -> 200 { profile }
//   POST { action: "reset_pin", id, temp_pin }                    -> 200 { ok }
//
// Authorization: an active admin's access token. Every action is logged with
// the admin's id; an update logs each changed field as { from, to }. Never
// logged: PINs and passwords.
//
// Accounts made here sign in with their user ID (as
// <user id>@staff.diamondagritech.internal). The contact email is only for
// reset codes, never a sign-in name. Only an account made directly in
// Supabase with a real email (the first admin) signs in with an email.
import type { Backend, Profile, ProfileChanges, Role } from '../_shared/backend.ts';
import { callerProfile } from '../_shared/caller.ts';
import { type Json, readBody, reply, str } from '../_shared/http.ts';
import {
  emailProblem,
  loginEmailFor,
  nameProblem,
  phoneProblem,
  pinProblem,
  userCodeProblem,
} from '../_shared/rules.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handler(req: Request, b: Backend): Promise<Response> {
  const body = await readBody(req);
  if (body instanceof Response) return body;

  const caller = await callerProfile(req, b);
  if (caller instanceof Response) return caller;
  if (caller.profile.role !== 'admin') return reply(403, { error: 'not_admin' });
  const admin = caller.profile;

  switch (body.action) {
    case 'create':
      return create(body, admin, b);
    case 'update':
      return update(body, admin, b);
    case 'reset_pin':
      return resetPin(body, admin, b);
    default:
      return reply(400, { error: 'unknown_action' });
  }
}

function role(value: unknown): Role | null {
  return value === 'admin' || value === 'employee' ? value : null;
}

async function create(body: Json, admin: Profile, b: Backend): Promise<Response> {
  const code = str(body, 'user_code');
  const name = str(body, 'full_name');
  const phone = str(body, 'phone');
  const email = str(body, 'contact_email').toLowerCase();
  const pin = typeof body.temp_pin === 'string' ? body.temp_pin : '';
  const newRole = body.role === undefined ? 'employee' : role(body.role);

  const fields: Record<string, string> = {};
  const problems: [string, string | null][] = [
    ['user_code', userCodeProblem(code)],
    ['full_name', nameProblem(name)],
    ['phone', phoneProblem(phone)],
    ['contact_email', emailProblem(email)],
    ['temp_pin', pinProblem(pin)],
    ['role', newRole ? null : 'Choose employee or admin'],
  ];
  for (const [k, v] of problems) if (v) fields[k] = v;
  if (Object.keys(fields).length > 0) return reply(400, { error: 'validation_failed', fields });

  if (await b.profileByCode(code)) return reply(409, { error: 'user_code_taken' });

  const id = await b.createAuthUser(
    loginEmailFor(code),
    pin,
    { role: newRole, must_change_password: true },
    name,
  );
  if (id === 'email_taken') return reply(409, { error: 'user_code_taken' });

  try {
    const inserted = await b.insertProfile({
      id,
      user_code: code,
      full_name: name,
      phone: phone || null,
      contact_email: email || null,
      role: newRole!,
      created_by: admin.id,
    });
    if (inserted === 'code_taken') {
      await removeHalfMadeAccount(id, b);
      return reply(409, { error: 'user_code_taken' });
    }
  } catch (e) {
    await removeHalfMadeAccount(id, b);
    throw e;
  }

  await b.logAdmin(admin.id, 'create_user', id, { user_code: code, role: newRole });
  return reply(201, { profile: await b.profile(id) });
}

async function update(body: Json, admin: Profile, b: Backend): Promise<Response> {
  const id = str(body, 'id');
  if (!UUID.test(id)) return reply(400, { error: 'validation_failed' });
  const target = await b.profile(id);
  if (!target) return reply(404, { error: 'user_not_found' });

  const changes: ProfileChanges = {};
  const fields: Record<string, string> = {};
  if ('full_name' in body) {
    const v = str(body, 'full_name');
    const p = nameProblem(v);
    if (p) fields.full_name = p;
    else changes.full_name = v;
  }
  if ('phone' in body) {
    const v = str(body, 'phone');
    const p = phoneProblem(v);
    if (p) fields.phone = p;
    else changes.phone = v || null;
  }
  if ('contact_email' in body) {
    const v = str(body, 'contact_email').toLowerCase();
    const p = emailProblem(v);
    if (p) fields.contact_email = p;
    else changes.contact_email = v || null;
  }
  if ('role' in body) {
    const r = role(body.role);
    if (!r) fields.role = 'Choose employee or admin';
    else changes.role = r;
  }
  if ('is_active' in body) {
    if (typeof body.is_active !== 'boolean') fields.is_active = 'Must be true or false';
    else changes.is_active = body.is_active;
  }
  if (Object.keys(fields).length > 0) return reply(400, { error: 'validation_failed', fields });

  // Only what really changes is saved and logged (the app sends every field).
  const diff: Record<string, { from: unknown; to: unknown }> = {};
  for (const [k, v] of Object.entries(changes) as [keyof ProfileChanges, unknown][]) {
    if (target[k] === v) delete changes[k];
    else diff[k] = { from: target[k], to: v };
  }
  if (Object.keys(changes).length === 0) return reply(200, { profile: target });

  // An admin cannot lock themselves out.
  if (id === admin.id && (changes.is_active === false || changes.role === 'employee')) {
    return reply(409, { error: 'cannot_change_own_access' });
  }

  // A new role goes on the sign-in account first, then on the profile. If the
  // profile save fails, the account is put back, so the app never shows the
  // admin side to someone the database treats as an employee (or the other
  // way round).
  let updated: Profile;
  if (changes.role) {
    await b.mergeAppMetadata(id, { role: changes.role });
    try {
      updated = await b.updateProfile(id, changes);
    } catch (e) {
      await b.mergeAppMetadata(id, { role: target.role });
      throw e;
    }
    await b.revokeSessions(id);
  } else {
    updated = await b.updateProfile(id, changes);
  }
  if (changes.is_active === false && !changes.role) {
    await b.revokeSessions(id);
  }
  await b.logAdmin(admin.id, 'update_user', id, { changes: diff });
  return reply(200, { profile: updated });
}

// Do not leave a sign-in account without a profile. If removing it fails too,
// the first error is kept (the caller re-throws it) and the leftover account is
// logged, so an admin can delete it in Supabase (L29). The id is not secret.
async function removeHalfMadeAccount(id: string, b: Backend): Promise<void> {
  try {
    await b.deleteAuthUser(id);
  } catch (e) {
    console.error(
      `admin-users create: sign-in account ${id} has no profile and could not be removed:`,
      e instanceof Error ? e.message : e,
    );
  }
}

async function resetPin(body: Json, admin: Profile, b: Backend): Promise<Response> {
  const id = str(body, 'id');
  const pin = typeof body.temp_pin === 'string' ? body.temp_pin : '';
  if (!UUID.test(id)) return reply(400, { error: 'validation_failed' });
  const p = pinProblem(pin);
  if (p) return reply(400, { error: 'validation_failed', fields: { temp_pin: p } });
  const target = await b.profile(id);
  if (!target) return reply(404, { error: 'user_not_found' });

  // The PIN and "must change password" are saved together.
  await b.setPassword(id, pin, { must_change_password: true });
  await b.logAdmin(admin.id, 'reset_pin', id, {});
  // Signs the user out everywhere and frees the phone lock (a lost or
  // replaced phone is handled this way). If only this fails, the new PIN
  // already works; pressing Reset again finishes it.
  try {
    await b.revokeSessions(id);
  } catch (e) {
    console.error('admin-users reset_pin: sign-out failed', e instanceof Error ? e.message : e);
    return reply(500, { error: 'reset_incomplete' });
  }
  return reply(200, { ok: true });
}
