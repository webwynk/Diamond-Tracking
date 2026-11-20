import { supabaseBackend } from '../_shared/backend.ts';
import { reply } from '../_shared/http.ts';
import { fcmSender, parseServiceAccount } from './fcm.ts';
import { handler } from './handler.ts';

const backend = supabaseBackend();
const account = parseServiceAccount(Deno.env.get('FCM_SERVICE_ACCOUNT'));
const sender = account ? fcmSender(account) : null;

Deno.serve(async (req) => {
  try {
    return await handler(req, backend, sender);
  } catch (e) {
    console.error('push failed:', e instanceof Error ? e.message : 'unknown');
    return reply(500, { error: 'server_error' });
  }
});
