import { supabaseBackend } from '../_shared/backend.ts';
import { reply } from '../_shared/http.ts';
import { handler } from './handler.ts';

const backend = supabaseBackend();

Deno.serve(async (req) => {
  try {
    return await handler(req, backend);
  } catch (e) {
    console.error('admin-users failed:', e instanceof Error ? e.message : 'unknown');
    return reply(500, { error: 'server_error' });
  }
});
