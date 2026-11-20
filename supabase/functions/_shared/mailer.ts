// Sends the password reset email through Resend (https://resend.com).
// Supabase's built-in email only reaches the project's own team, so a real
// email service is needed. Without RESEND_API_KEY, email reset is off and
// users ask the admin to reset their PIN instead.

export interface Mailer {
  readonly configured: boolean;
  send(to: string, subject: string, text: string): Promise<boolean>;
}

export function resendMailer(): Mailer {
  const key = Deno.env.get('RESEND_API_KEY') ?? '';
  const from = Deno.env.get('RESET_EMAIL_FROM') ?? '';
  return {
    configured: key !== '' && from !== '',
    async send(to, subject, text) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
        body: JSON.stringify({ from, to: [to], subject, text }),
      });
      await res.body?.cancel();
      return res.ok;
    },
  };
}
