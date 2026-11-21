// Sends the password reset email through Resend (https://resend.com).
// Supabase's built-in email only reaches the project's own team, so a real
// email service is needed. Without RESEND_API_KEY, email reset is off and
// users ask the admin to reset their PIN instead.

export interface Mailer {
  readonly configured: boolean;
  /** True when Resend accepted the email. Never throws. */
  send(to: string, subject: string, text: string): Promise<boolean>;
}

/** The longest wait for Resend before giving up (L34). */
export const SEND_TIMEOUT_MS = 10_000;

/** Settings for tests. The live function uses the defaults. */
export interface ResendOptions {
  key?: string;
  from?: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
}

export function resendMailer(options: ResendOptions = {}): Mailer {
  const key = options.key ?? Deno.env.get('RESEND_API_KEY') ?? '';
  const from = options.from ?? Deno.env.get('RESET_EMAIL_FROM') ?? '';
  const fetcher = options.fetcher ?? fetch;
  const timeoutMs = options.timeoutMs ?? SEND_TIMEOUT_MS;
  return {
    configured: key !== '' && from !== '',
    async send(to, subject, text) {
      // A slow or broken Resend must not keep the user waiting: give up after
      // timeoutMs. A failed send is logged (never the address or the code)
      // and gives the same answer to the user as a sent one, so the reply
      // still does not reveal which user IDs exist. The user asks again.
      const abort = new AbortController();
      const timer = setTimeout(() => abort.abort(), timeoutMs);
      try {
        const res = await fetcher('https://api.resend.com/emails', {
          method: 'POST',
          headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
          body: JSON.stringify({ from, to: [to], subject, text }),
          signal: abort.signal,
        });
        await res.body?.cancel();
        if (!res.ok) console.error('reset email not sent: Resend answered', res.status);
        return res.ok;
      } catch (e) {
        let reason = e instanceof Error ? e.message : 'unknown';
        if (abort.signal.aborted) reason = `no answer in ${timeoutMs} ms`;
        console.error('reset email not sent:', reason);
        return false;
      } finally {
        clearTimeout(timer);
      }
    },
  };
}
