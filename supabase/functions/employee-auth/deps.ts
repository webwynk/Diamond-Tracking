// What the employee-auth routes need from the outside world. The real versions
// are wired in index.ts; the tests use fakes.

export type LoginCheck =
  | {
    result: 'ok';
    user_id: string;
    email: string;
    login_password: string;
    must_change_pin: boolean;
  }
  | { result: 'invalid' }
  | { result: 'blocked' }
  | { result: 'locked'; retry_after_seconds: number };

export type Session = {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at: number | null;
  token_type: string;
};

export type ProfileRow = {
  id: string;
  role: string;
  status: string;
  must_change_pin: boolean;
};

/** A PIN the rules refuse: the reason, in words the person can act on. */
export type PinResult = { ok: true } | { ok: false; problem: string };

export type Deps = {
  /** public.employee_login_check, called with the server key. */
  loginCheck(code: string, pin: string): Promise<LoginCheck>;
  /** Signs in to Supabase Auth with the derived password. Null if refused. */
  signIn(email: string, password: string): Promise<Session | null>;
  /** The signed-in user behind this Authorization header, if any. */
  userId(auth: string): Promise<string | null>;
  /** public.is_admin() as the caller. */
  isAdmin(auth: string): Promise<boolean>;
  profileOf(userId: string): Promise<ProfileRow | null>;
  /** public.set_employee_pin with the server key. */
  setPin(userId: string, pin: string, mustChange: boolean): Promise<PinResult>;
  /** public.admin_reset_pin with the server key (PIN + audit row together). */
  adminResetPin(actorId: string, userId: string, pin: string): Promise<PinResult>;
};
