import { supabaseBackend } from '../_shared/backend.ts';
import { reply } from '../_shared/http.ts';
import type { CloudinaryConfig } from './cloudinary.ts';
import { handler } from './handler.ts';

const backend = supabaseBackend();
const cloudName = Deno.env.get('CLOUDINARY_CLOUD_NAME');
const apiKey = Deno.env.get('CLOUDINARY_API_KEY');
const apiSecret = Deno.env.get('CLOUDINARY_API_SECRET');
const cloudinary: CloudinaryConfig | null = cloudName && apiKey && apiSecret
  ? { cloudName, apiKey, apiSecret }
  : null;

Deno.serve(async (req) => {
  try {
    return await handler(req, backend, {
      cloudinary,
      fetcher: fetch,
      now: Date.now,
      newId: () => crypto.randomUUID(),
    });
  } catch (e) {
    console.error('photos failed:', e instanceof Error ? e.message : 'unknown');
    return reply(500, { error: 'server_error' });
  }
});
