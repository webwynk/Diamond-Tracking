// Small HTTP helpers shared by the Edge Functions.

export type Json = Record<string, unknown>;

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

export function reply(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...CORS },
  });
}

/** Reads a POST JSON body, or returns the error reply to send. */
export async function readBody(req: Request): Promise<Json | Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
  try {
    const body = await req.json();
    if (typeof body !== 'object' || body === null || Array.isArray(body)) {
      return reply(400, { error: 'validation_failed' });
    }
    return body as Json;
  } catch {
    return reply(400, { error: 'validation_failed' });
  }
}

/** The bearer token from the Authorization header, or null. */
export function bearer(req: Request): string | null {
  const h = req.headers.get('authorization') ?? '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1] : null;
}

export function str(body: Json, key: string): string {
  const v = body[key];
  return typeof v === 'string' ? v.trim() : '';
}
