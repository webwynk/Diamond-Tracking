// Firebase Cloud Messaging (HTTP v1) with a service account.

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface PushMessage {
  title: string;
  body: string | null;
  data: Record<string, string>;
}

/** 'sent', 'gone' (the token no longer works: drop it) or 'failed'. */
export type SendResult = 'sent' | 'gone' | 'failed';

export interface Sender {
  send(token: string, message: PushMessage): Promise<SendResult>;
}

export function parseServiceAccount(raw: string | undefined): ServiceAccount | null {
  if (!raw) return null;
  try {
    const sa = JSON.parse(raw) as Partial<ServiceAccount>;
    if (!sa.project_id || !sa.client_email || !sa.private_key) return null;
    return sa as ServiceAccount;
  } catch {
    return null;
  }
}

function base64Url(bytes: Uint8Array | string): string {
  const b = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
  let binary = '';
  for (const x of b) binary += String.fromCharCode(x);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/** The signed JWT that is traded for an access token. */
export async function signedJwt(sa: ServiceAccount, nowSec: number): Promise<string> {
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: sa.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: nowSec,
    exp: nowSec + 3600,
  }));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64Url(new Uint8Array(sig))}`;
}

/** The FCM message body for one phone. */
export function fcmBody(token: string, m: PushMessage) {
  return {
    message: {
      token,
      notification: { title: m.title, ...(m.body ? { body: m.body } : {}) },
      data: m.data,
      android: { priority: 'high', notification: { channel_id: 'requests' } },
    },
  };
}

export function fcmSender(
  sa: ServiceAccount,
  fetcher: typeof fetch = fetch,
  now: () => number = Date.now,
): Sender {
  let cached: { token: string; until: number } | null = null;

  async function accessToken(): Promise<string> {
    if (cached && cached.until > now()) return cached.token;
    const res = await fetcher(sa.token_uri ?? 'https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: await signedJwt(sa, Math.floor(now() / 1000)),
      }),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) throw new Error(`oauth http ${res.status}`);
    const body = await res.json() as { access_token: string; expires_in: number };
    cached = { token: body.access_token, until: now() + (body.expires_in - 120) * 1000 };
    return body.access_token;
  }

  return {
    async send(token, message) {
      const res = await fetcher(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${await accessToken()}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify(fcmBody(token, message)),
          signal: AbortSignal.timeout(10000),
        },
      );
      if (res.ok) return 'sent';
      const text = await res.text();
      // The app was removed or its data cleared, or the token is malformed.
      if (res.status === 404 || /UNREGISTERED|registration token is not valid/i.test(text)) {
        return 'gone';
      }
      console.error('fcm send failed:', res.status);
      return 'failed';
    },
  };
}
