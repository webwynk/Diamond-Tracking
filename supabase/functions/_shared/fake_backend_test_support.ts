// An in-memory Backend for the handler tests.
import type {
  Backend,
  MissingPlace,
  NewProfile,
  Profile,
  ProfileChanges,
  PushJob,
} from './backend.ts';
import type { Mailer } from './mailer.ts';

export class FakeBackend implements Backend {
  profiles = new Map<string, Profile>();
  tokens = new Map<string, string>(); // token -> user id
  meta = new Map<string, Record<string, unknown>>();
  passwords = new Map<string, string>();
  emails = new Map<string, string>(); // auth email -> id
  revoked: string[] = [];
  log: { admin: string; action: string; target: string }[] = [];
  codes = new Map<string, string>();
  failInsert = false;
  /** day id -> owner id, and the stops still needing an address. */
  dayOwners = new Map<number, string>();
  missing: MissingPlace[] = [];
  saved: { cell_lat: number; cell_lng: number; address: string }[] = [];
  /** request id -> owner and photo id. */
  requests = new Map<number, { owner: string; photo: string | null }>();
  /** visit id -> owner and photo id. */
  visits = new Map<string, { owner: string; photo: string | null }>();
  /** photos past 90 days, and those marked removed. */
  oldPhotos: string[] = [];
  removedPhotos: string[] = [];
  /** notification id -> push job (removed when claimed). */
  pushJobs = new Map<number, PushJob>();
  droppedTokens: string[] = [];
  private next = 1;

  addUser(
    p: Partial<Profile> & { user_code: string },
    token?: string,
    meta: Record<string, unknown> = {},
  ) {
    const id = p.id ?? `00000000-0000-0000-0000-${String(this.next++).padStart(12, '0')}`;
    this.profiles.set(id, {
      id,
      full_name: 'Someone',
      phone: null,
      contact_email: null,
      role: 'employee',
      is_active: true,
      ...p,
    });
    this.emails.set(`${p.user_code.toLowerCase()}@staff.diamondagritech.internal`, id);
    this.meta.set(id, { role: p.role ?? 'employee', ...meta });
    if (token) this.tokens.set(token, id);
    return id;
  }

  userFromToken(token: string) {
    const id = this.tokens.get(token);
    return Promise.resolve(id ? { id, appMetadata: this.meta.get(id) ?? {} } : null);
  }
  profile(id: string) {
    return Promise.resolve(this.profiles.get(id) ?? null);
  }
  profileByCode(code: string) {
    for (const p of this.profiles.values()) {
      if (p.user_code.toLowerCase() === code.toLowerCase()) return Promise.resolve(p);
    }
    return Promise.resolve(null);
  }
  createAuthUser(email: string, password: string, appMetadata: Record<string, unknown>) {
    if (this.emails.has(email)) return Promise.resolve('email_taken' as const);
    const id = `00000000-0000-0000-0000-${String(this.next++).padStart(12, '0')}`;
    this.emails.set(email, id);
    this.passwords.set(id, password);
    this.meta.set(id, appMetadata);
    return Promise.resolve(id);
  }
  deleteAuthUser(id: string) {
    for (const [e, i] of this.emails) if (i === id) this.emails.delete(e);
    this.meta.delete(id);
    return Promise.resolve();
  }
  insertProfile(p: NewProfile) {
    if (this.failInsert) return Promise.reject(new Error('db down'));
    this.profiles.set(p.id, { ...p, is_active: true });
    return Promise.resolve('ok' as const);
  }
  updateProfile(id: string, changes: ProfileChanges) {
    const p = { ...this.profiles.get(id)!, ...changes };
    this.profiles.set(id, p);
    return Promise.resolve(p);
  }
  setPassword(id: string, password: string) {
    this.passwords.set(id, password);
    return Promise.resolve();
  }
  mergeAppMetadata(id: string, values: Record<string, unknown>) {
    this.meta.set(id, { ...(this.meta.get(id) ?? {}), ...values });
    return Promise.resolve();
  }
  revokeSessions(id: string) {
    this.revoked.push(id);
    return Promise.resolve();
  }
  storeResetCode(id: string, code: string) {
    this.codes.set(id, code);
    return Promise.resolve(true);
  }
  useResetCode(id: string, code: string) {
    const ok = this.codes.get(id) === code;
    if (ok) this.codes.delete(id);
    return Promise.resolve(ok);
  }
  missingPlaces(dayId: number, callerId: string) {
    const owner = this.dayOwners.get(dayId);
    const caller = this.profiles.get(callerId);
    if (!owner || !caller || (owner !== callerId && caller.role !== 'admin')) {
      return Promise.resolve('not_allowed' as const);
    }
    return Promise.resolve(this.missing);
  }
  savePlaces(_dayId: number, places: { cell_lat: number; cell_lng: number; address: string }[]) {
    this.saved.push(...places);
    return Promise.resolve();
  }
  requestPhoto(requestId: number, callerId: string) {
    const r = this.requests.get(requestId);
    const caller = this.profiles.get(callerId);
    if (!r || !caller || (r.owner !== callerId && caller.role !== 'admin')) {
      return Promise.resolve('not_allowed' as const);
    }
    return Promise.resolve(r.photo);
  }
  visitPhoto(visitId: string, callerId: string) {
    const v = this.visits.get(visitId);
    const caller = this.profiles.get(callerId);
    if (!v || !caller || (v.owner !== callerId && caller.role !== 'admin')) {
      return Promise.resolve('not_allowed' as const);
    }
    return Promise.resolve(v.photo);
  }
  photosToPurge(limit: number) {
    return Promise.resolve(
      this.oldPhotos.filter((p) => !this.removedPhotos.includes(p)).slice(0, limit),
    );
  }
  photosRemoved(photoIds: string[]) {
    this.removedPhotos.push(...photoIds);
    return Promise.resolve();
  }
  claimPush(id: number) {
    const job = this.pushJobs.get(id) ?? null;
    this.pushJobs.delete(id);
    return Promise.resolve(job);
  }
  dropPushTokens(tokens: string[]) {
    this.droppedTokens.push(...tokens);
    return Promise.resolve();
  }
  logAdmin(admin: string, action: string, target: string) {
    this.log.push({ admin, action, target });
    return Promise.resolve();
  }
}

export class FakeMailer implements Mailer {
  sent: { to: string; text: string }[] = [];
  constructor(readonly configured = true) {}
  send(to: string, _subject: string, text: string) {
    this.sent.push({ to, text });
    return Promise.resolve(true);
  }
}

export function post(body: unknown, token?: string): Request {
  return new Request('http://local/fn', {
    method: 'POST',
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });
}
