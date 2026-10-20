// employee-auth: wires the real Supabase to the routes in handler.ts. All the
// rules are in handler.ts and in the database; they are tested without this file.

import { createClient } from 'npm:@supabase/supabase-js@2';
import type { Deps, LoginCheck, PinResult, ProfileRow, Session } from './deps.ts';
import { handler } from './handler.ts';

function realDeps(): Deps {
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  const asCaller = (auth: string) =>
    createClient(url, anonKey, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    });
  const server = createClient(url, serviceKey, { auth: { persistSession: false } });

  /** set_employee_pin and admin_reset_pin report a refused PIN as 'pin_invalid'. */
  const pinResult = (error: { message?: string; details?: string } | null): PinResult => {
    if (!error) return { ok: true };
    if (error.message === 'pin_invalid') {
      return { ok: false, problem: error.details ?? 'Choose a different PIN' };
    }
    throw new Error('pin_not_set');
  };

  return {
    async loginCheck(code, pin) {
      const { data, error } = await server.rpc('employee_login_check', {
        p_code: code,
        p_pin: pin,
      });
      if (error || !data) throw new Error('login_check_failed');
      return data as LoginCheck;
    },

    async signIn(email, password) {
      const anon = createClient(url, anonKey, { auth: { persistSession: false } });
      const { data, error } = await anon.auth.signInWithPassword({ email, password });
      if (error || !data.session) return null;
      const s = data.session;
      const session: Session = {
        access_token: s.access_token,
        refresh_token: s.refresh_token,
        expires_in: s.expires_in,
        expires_at: s.expires_at ?? null,
        token_type: s.token_type,
      };
      return session;
    },

    async userId(auth) {
      const { data, error } = await asCaller(auth).auth.getUser();
      return error || !data.user ? null : data.user.id;
    },

    async isAdmin(auth) {
      const { data, error } = await asCaller(auth).rpc('is_admin');
      return !error && data === true;
    },

    async profileOf(userId) {
      const { data, error } = await server
        .from('profiles')
        .select('id, role, status, must_change_pin')
        .eq('id', userId)
        .maybeSingle();
      if (error) throw error;
      return data as ProfileRow | null;
    },

    async setPin(userId, pin, mustChange) {
      const { error } = await server.rpc('set_employee_pin', {
        p_user: userId,
        p_pin: pin,
        p_must_change: mustChange,
      });
      return pinResult(error);
    },

    async adminResetPin(actorId, userId, pin) {
      const { error } = await server.rpc('admin_reset_pin', {
        p_actor: actorId,
        p_user: userId,
        p_pin: pin,
      });
      return pinResult(error);
    },
  };
}

const deps = realDeps();

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    return await handler(req, deps);
  } catch {
    // Never let an unexpected error carry text back to the caller.
    return new Response(JSON.stringify({ error: 'server_error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
