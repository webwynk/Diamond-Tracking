import { supabaseBackend } from '../_shared/backend.ts';
import { reply } from '../_shared/http.ts';
import { resendMailer } from '../_shared/mailer.ts';
import { handler } from './handler.ts';

const backend = supabaseBackend();
const mailer = resendMailer();

Deno.serve(async (req) => {
  try {
    return await handler(req, backend, mailer);
  } catch (e) {
    console.error('password-reset failed:', e instanceof Error ? e.message : 'unknown');
    return reply(500, { error: 'server_error' });
  }
});
