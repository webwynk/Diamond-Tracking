// Input rules, the same as the database checks and the app's validators.

/** Sign-in emails are derived from the user ID; the domain never receives mail. */
export const LOGIN_EMAIL_DOMAIN = 'staff.diamondagritech.internal';

export function loginEmailFor(userCode: string): string {
  return `${userCode.toLowerCase()}@${LOGIN_EMAIL_DOMAIN}`;
}

export function userCodeProblem(code: string): string | null {
  return /^[A-Za-z0-9][A-Za-z0-9_-]{1,19}$/.test(code)
    ? null
    : 'Use 2 to 20 letters, digits, - or _';
}

export function nameProblem(name: string): string | null {
  return name.length >= 1 && name.length <= 80 ? null : 'Enter a name up to 80 characters';
}

export function phoneProblem(phone: string): string | null {
  return phone === '' || /^\+?[0-9]{7,15}$/.test(phone) ? null : 'Enter a valid phone number';
}

export function emailProblem(email: string): string | null {
  if (email === '') return null;
  return email.length <= 120 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ? null
    : 'Enter a valid email address or leave it empty';
}

/** Temporary PIN chosen by the admin: exactly 6 digits, not all the same. */
export function pinProblem(pin: string): string | null {
  if (!/^[0-9]{6}$/.test(pin)) return 'The temporary PIN must be 6 digits';
  if (/^(\d)\1{5}$/.test(pin)) return 'Do not use the same digit 6 times';
  return null;
}

/** The user's own password: 8 to 72 characters with a letter and a digit. */
export function passwordProblem(password: string, userCode: string): string | null {
  if (password.length < 8 || password.length > 72) return 'Use 8 to 72 characters';
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    return 'Use at least one letter and one digit';
  }
  if (userCode !== '' && password.toLowerCase().includes(userCode.toLowerCase())) {
    return 'Do not use your user ID in the password';
  }
  return null;
}
