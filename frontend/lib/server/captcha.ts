import "server-only";

import { CAPTCHA_BYPASS_HEADER, CAPTCHA_FORM_FIELD, CAPTCHA_TOKEN_HEADER } from "@/lib/captcha";

// Header carrying the browser's Turnstile token to the backend gate.
export function captchaHeaders(formData: FormData): Record<string, string> {
  return { [CAPTCHA_TOKEN_HEADER]: (formData.get(CAPTCHA_FORM_FIELD) ?? "").toString() };
}

// Header for this server's own calls (demo login, admin password reset) that
// have no browser widget; empty when CAPTCHA_BYPASS_SECRET is unset.
export function captchaBypassHeaders(): Record<string, string> {
  const secret = process.env.CAPTCHA_BYPASS_SECRET;
  return secret ? { [CAPTCHA_BYPASS_HEADER]: secret } : {};
}
