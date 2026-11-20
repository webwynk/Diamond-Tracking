import { supabaseBackend } from '../_shared/backend.ts';
import { reply } from '../_shared/http.ts';
import { googleGeocoder } from './geocode.ts';
import { handler } from './handler.ts';

const backend = supabaseBackend();
const key = Deno.env.get('GOOGLE_GEOCODING_KEY');
const geocoder = key ? googleGeocoder(key) : null;

Deno.serve(async (req) => {
  try {
    return await handler(req, backend, geocoder);
  } catch (e) {
    console.error('stop-addresses failed:', e instanceof Error ? e.message : 'unknown');
    return reply(500, { error: 'server_error' });
  }
});
