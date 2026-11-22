// L37: the server's rules give the same verdict as the app's on every case
// in rule_cases.json (the app's test reads the same file).
import { assertEquals } from '@std/assert';
import cases from './rule_cases.json' with { type: 'json' };
import {
  designationProblem,
  emailProblem,
  nameProblem,
  passwordProblem,
  phoneProblem,
  pinProblem,
  userCodeProblem,
} from './rules.ts';

const checks: Record<string, (v: string) => string | null> = {
  user_code: userCodeProblem,
  name: nameProblem,
  phone: phoneProblem,
  email: emailProblem,
  designation: (v) => designationProblem(v, false),
  designation_required: (v) => designationProblem(v, true),
  pin: pinProblem,
  password: (v) => passwordProblem(v, cases.password.user_code),
};

for (const [kind, check] of Object.entries(checks)) {
  Deno.test(`${kind} rules match the shared cases`, () => {
    const set = cases[kind as keyof typeof cases] as { ok: string[]; bad: string[] };
    for (const v of set.ok) assertEquals(check(v), null, `${kind} should accept ${v}`);
    for (const v of set.bad) {
      assertEquals(check(v) !== null, true, `${kind} should refuse ${v}`);
    }
  });
}
