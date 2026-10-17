// Small response helpers shared by the Edge Functions.

export type Json = Record<string, unknown>;

export function reply(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** The Cloudinary settings, read from the function's secrets. Never logged. */
export type CloudConfig = { name: string; apiKey: string; apiSecret: string };

/** Null when any of the three secrets is missing. */
export function cloudConfig(): CloudConfig | null {
  const name = Deno.env.get('CLOUDINARY_CLOUD_NAME');
  const apiKey = Deno.env.get('CLOUDINARY_API_KEY');
  const apiSecret = Deno.env.get('CLOUDINARY_API_SECRET');
  if (!name || !apiKey || !apiSecret) return null;
  return { name, apiKey, apiSecret };
}
