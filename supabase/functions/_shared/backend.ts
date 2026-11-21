// Everything the functions need from Supabase, behind one interface so the
// handlers can be tested with a fake.
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export type Role = 'employee' | 'admin';

export interface Profile {
  id: string;
  user_code: string;
  full_name: string;
  phone: string | null;
  contact_email: string | null;
  role: Role;
  is_active: boolean;
}

export interface NewProfile {
  id: string;
  user_code: string;
  full_name: string;
  phone: string | null;
  contact_email: string | null;
  role: Role;
  created_by: string;
}

export type ProfileChanges = Partial<
  Pick<Profile, 'full_name' | 'phone' | 'contact_email' | 'role' | 'is_active'>
>;

/** A stop that still needs an address. */
export interface MissingPlace {
  cell_lat: number;
  cell_lng: number;
  lat: number;
  lng: number;
}

/** What the push function sends for one notification. */
export interface PushJob {
  title: string;
  body: string | null;
  kind: string;
  data: Record<string, unknown>;
  tokens: string[];
}

export interface Backend {
  /** The signed-in user behind an access token, or null if it is not valid. */
  userFromToken(
    token: string,
  ): Promise<{ id: string; appMetadata: Record<string, unknown> } | null>;
  profile(id: string): Promise<Profile | null>;
  profileByCode(userCode: string): Promise<Profile | null>;
  /** Creates the sign-in account. Returns its id, or 'email_taken'. */
  createAuthUser(
    email: string,
    password: string,
    appMetadata: Record<string, unknown>,
    fullName: string,
  ): Promise<string | 'email_taken'>;
  deleteAuthUser(id: string): Promise<void>;
  insertProfile(p: NewProfile): Promise<'ok' | 'code_taken'>;
  updateProfile(id: string, changes: ProfileChanges): Promise<Profile>;
  /** Sets the password and, in the same save, merges [appMetadata] into the
   * account's app_metadata, so the two never end up half done. */
  setPassword(id: string, password: string, appMetadata?: Record<string, unknown>): Promise<void>;
  /** Merges keys into the account's app_metadata (server-only claims). */
  mergeAppMetadata(id: string, values: Record<string, unknown>): Promise<void>;
  revokeSessions(id: string): Promise<void>;
  storeResetCode(id: string, code: string): Promise<boolean>;
  useResetCode(id: string, code: string): Promise<boolean>;
  logAdmin(
    adminId: string,
    action: string,
    target: string,
    details: Record<string, unknown>,
  ): Promise<void>;
  /** Stops of a day without an address, or 'not_allowed' for this caller. */
  missingPlaces(dayId: number, callerId: string): Promise<MissingPlace[] | 'not_allowed'>;
  savePlaces(
    dayId: number,
    places: { cell_lat: number; cell_lng: number; address: string }[],
  ): Promise<void>;
  /** A request's photo id (null if none), or 'not_allowed' for this caller. */
  /** Photo [index] of a request: 0 is the first, 1 and 2 the extra photos. */
  requestPhoto(
    requestId: number,
    callerId: string,
    index: number,
  ): Promise<string | null | 'not_allowed'>;
  /** A visit's photo id (null if none or removed), or 'not_allowed' for this caller. */
  visitPhoto(visitId: string, callerId: string): Promise<string | null | 'not_allowed'>;
  /** Counts one photo upload for today; false when today's 60 are used up. */
  countPhotoUpload(userId: string): Promise<boolean>;
  /** Notes a signed photo id, so an unused one is deleted later (L56). */
  noteSignedPhoto(photoId: string): Promise<void>;
  /** Photos to delete: older than 90 days, or signed and never used. */
  photosToPurge(limit: number): Promise<string[]>;
  /** Marks photos as deleted from Cloudinary. */
  photosRemoved(photoIds: string[]): Promise<void>;
  /** Claims a notification for pushing; null if gone or already pushed. */
  claimPush(id: number): Promise<PushJob | null>;
  dropPushTokens(tokens: string[]): Promise<void>;
}

const PROFILE_COLUMNS = 'id, user_code, full_name, phone, contact_email, role, is_active';

/** The project's secret key: the new named keys first, the legacy one second. */
export function secretKey(): string {
  const named = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (named) {
    try {
      const parsed = JSON.parse(named) as Record<string, string>;
      if (parsed.default) return parsed.default;
    } catch {
      // fall through to the legacy name
    }
  }
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!legacy) throw new Error('No secret key in the environment');
  return legacy;
}

function check<T>(result: { data: T; error: { message: string } | null }): T {
  if (result.error) throw new Error(result.error.message);
  return result.data;
}

/** `ilike` treats _ and % as wildcards; user codes may contain _. */
function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (c) => `\\${c}`);
}

export function supabaseBackend(): Backend {
  const url = Deno.env.get('SUPABASE_URL');
  if (!url) throw new Error('SUPABASE_URL is not set');
  const db: SupabaseClient = createClient(url, secretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    async userFromToken(token) {
      const { data, error } = await db.auth.getUser(token);
      if (error || !data.user) return null;
      return { id: data.user.id, appMetadata: data.user.app_metadata ?? {} };
    },
    async profile(id) {
      const row = check(
        await db.from('profiles').select(PROFILE_COLUMNS).eq('id', id).maybeSingle(),
      );
      return (row as Profile | null) ?? null;
    },
    async profileByCode(userCode) {
      const row = check(
        await db.from('profiles').select(PROFILE_COLUMNS).ilike('user_code', escapeLike(userCode))
          .maybeSingle(),
      );
      return (row as Profile | null) ?? null;
    },
    async createAuthUser(email, password, appMetadata, fullName) {
      const { data, error } = await db.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        app_metadata: appMetadata,
        user_metadata: { full_name: fullName },
      });
      if (error) {
        if (error.code === 'email_exists' || /already/i.test(error.message)) return 'email_taken';
        throw new Error(error.message);
      }
      return data.user.id;
    },
    async deleteAuthUser(id) {
      await db.auth.admin.deleteUser(id);
    },
    async insertProfile(p) {
      const { error } = await db.from('profiles').insert(p);
      if (error) {
        if (error.code === '23505') return 'code_taken';
        throw new Error(error.message);
      }
      return 'ok';
    },
    async updateProfile(id, changes) {
      const row = check(
        await db.from('profiles').update(changes).eq('id', id).select(PROFILE_COLUMNS).single(),
      );
      if (!row) throw new Error('Profile not found after update');
      return row as Profile;
    },
    async setPassword(id, password, appMetadata) {
      let app_metadata: Record<string, unknown> | undefined;
      if (appMetadata) {
        const { data, error } = await db.auth.admin.getUserById(id);
        if (error) throw new Error(error.message);
        app_metadata = { ...(data.user.app_metadata ?? {}), ...appMetadata };
      }
      const { error } = await db.auth.admin.updateUserById(
        id,
        app_metadata ? { password, app_metadata } : { password },
      );
      if (error) throw new Error(error.message);
    },
    async mergeAppMetadata(id, values) {
      const { data, error } = await db.auth.admin.getUserById(id);
      if (error) throw new Error(error.message);
      const merged = { ...(data.user.app_metadata ?? {}), ...values };
      const res = await db.auth.admin.updateUserById(id, { app_metadata: merged });
      if (res.error) throw new Error(res.error.message);
    },
    async revokeSessions(id) {
      check(await db.rpc('svc_revoke_sessions', { p_user: id }));
    },
    async storeResetCode(id, code) {
      return check(await db.rpc('svc_store_reset_code', { p_user: id, p_code: code })) === true;
    },
    async useResetCode(id, code) {
      return check(await db.rpc('svc_use_reset_code', { p_user: id, p_code: code })) === true;
    },
    async missingPlaces(dayId, callerId) {
      const { data, error } = await db.rpc('svc_missing_places', {
        p_day_id: dayId,
        p_caller: callerId,
      });
      if (error) {
        if (/not_allowed/.test(error.message)) return 'not_allowed';
        throw new Error(error.message);
      }
      return (data ?? []) as MissingPlace[];
    },
    async savePlaces(dayId, places) {
      check(await db.rpc('svc_save_places', { p_day_id: dayId, p_places: places }));
    },
    async requestPhoto(requestId, callerId, index) {
      const { data, error } = await db.rpc('svc_request_photo', {
        p_request_id: requestId,
        p_caller: callerId,
        p_index: index,
      });
      if (error) {
        if (/not_allowed/.test(error.message)) return 'not_allowed';
        throw new Error(error.message);
      }
      return (data as string | null) ?? null;
    },
    async visitPhoto(visitId, callerId) {
      const { data, error } = await db.rpc('svc_visit_photo', {
        p_visit_id: visitId,
        p_caller: callerId,
      });
      if (error) {
        if (/not_allowed/.test(error.message)) return 'not_allowed';
        throw new Error(error.message);
      }
      return (data as string | null) ?? null;
    },
    async countPhotoUpload(userId) {
      return check(await db.rpc('svc_count_photo_upload', { p_user: userId })) === true;
    },
    async noteSignedPhoto(photoId) {
      check(await db.rpc('svc_note_signed_photo', { p_photo_id: photoId }));
    },
    async photosToPurge(limit) {
      const rows = check(await db.rpc('svc_photos_to_purge', { p_limit: limit })) as
        | { photo_id: string }[]
        | null;
      return (rows ?? []).map((r) => r.photo_id);
    },
    async photosRemoved(photoIds) {
      check(await db.rpc('svc_photos_removed', { p_photo_ids: photoIds }));
    },
    async claimPush(id) {
      return (check(await db.rpc('svc_claim_push', { p_id: id })) as PushJob | null) ?? null;
    },
    async dropPushTokens(tokens) {
      check(await db.rpc('svc_drop_push_tokens', { p_tokens: tokens }));
    },
    async logAdmin(adminId, action, target, details) {
      check(
        await db.rpc('svc_log_admin', {
          p_admin: adminId,
          p_action: action,
          p_target: target,
          p_details: details,
        }),
      );
    },
  };
}
