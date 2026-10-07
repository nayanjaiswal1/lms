export const TURNSTILE_SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js";
export const TURNSTILE_ORIGIN = "https://challenges.cloudflare.com";

// FormData key the client forms use to hand the Turnstile token to server actions.
export const CAPTCHA_FORM_FIELD = "captchaToken";

// Backend request headers (see backend/internal/middleware/captcha.go).
export const CAPTCHA_TOKEN_HEADER = "X-Captcha-Token";
export const CAPTCHA_BYPASS_HEADER = "X-Captcha-Bypass";
