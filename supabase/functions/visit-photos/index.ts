// visit-photos: wires the real Supabase and Cloudinary to the routes in
// handler.ts. All the rules are in handler.ts, employee.ts, view.ts and
// purge.ts, which are tested without this file.

import { createClient } from 'npm:@supabase/supabase-js@2';
import type { Deps, DuePhoto, VisitRow } from './deps.ts';
import { handler } from './handler.ts';
import { cloudConfig } from './http.ts';

function realDeps(): Deps {
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  /** A client that acts as the caller, so row-level security decides. */
  const asCaller = (auth: string) =>
    createClient(url, anonKey, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    });
  /** The privileged client: only for what the caller must not do themselves. */
  const server = createClient(url, serviceKey, { auth: { persistSession: false } });

  return {
    cloud: cloudConfig(),
    purgeToken: Deno.env.get('PURGE_TOKEN') ?? null,
    now: () => new Date(),
    fetch: (input, init) => fetch(input, init),

    async userId(auth) {
      const { data, error } = await asCaller(auth).auth.getUser();
      return error || !data.user ? null : data.user.id;
    },

    async isAdmin(auth) {
      const { data, error } = await asCaller(auth).rpc('is_admin');
      return !error && data === true;
    },

    async readVisit(auth, visitId) {
      const { data, error } = await asCaller(auth)
        .from('visits')
        .select('id, employee_id, photo_public_id, photo_removed_at, created_at')
        .eq('id', visitId)
        .maybeSingle();
      if (error) throw error;
      return data as VisitRow | null;
    },

    async attachPhoto(visitId, publicId, at) {
      const { data, error } = await server
        .from('visits')
        .update({ photo_public_id: publicId, photo_attached_at: at.toISOString() })
        .eq('id', visitId)
        .is('photo_public_id', null)
        .is('photo_removed_at', null)
        .select('id');
      if (error) throw error;
      return (data?.length ?? 0) === 1;
    },

    async dueForPurge(cutoff, limit) {
      const { data, error } = await server
        .from('visits')
        .select('id, photo_public_id')
        .not('photo_public_id', 'is', null)
        .lt('created_at', cutoff.toISOString())
        .order('created_at', { ascending: true })
        .limit(limit);
      if (error) throw error;
      return (data ?? []) as DuePhoto[];
    },

    async markPhotoRemoved(visitId, at) {
      const { error } = await server
        .from('visits')
        .update({ photo_public_id: null, photo_removed_at: at.toISOString() })
        .eq('id', visitId);
      if (error) throw error;
    },

    async audit(action, details) {
      const { error } = await server.from('audit_log').insert({ action, details });
      if (error) throw error;
    },
  };
}

Deno.serve((req: Request): Promise<Response> => handler(req, realDeps()));
