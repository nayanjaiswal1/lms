// ─────────────────────────────────────────────
// Auth validation — single source of truth for the login schema and the
// user-facing copy. Imported by BOTH the client form (live validation) and
// the server action (boundary validation), so the two never drift.
// ─────────────────────────────────────────────

import { z } from "zod";

// Pragmatic email shape — full RFC 5322 is overkill and rejects valid
// addresses. The backend remains the authority on whether the account exists.
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const loginSchema = z.object({
  email: z
    .string()
    .trim()
    .min(1, "Enter your email address")
    .regex(EMAIL_PATTERN, "Enter a valid email address"),
  // Login never enforces complexity — that belongs to registration. We only
  // require a non-empty value so the request is well-formed.
  password: z.string().min(1, "Enter your password"),
});

export type LoginInput = z.infer<typeof loginSchema>;

export const registerSchema = z
  .object({
    name: z
      .string()
      .trim()
      .min(2, "Enter your full name")
      .max(80, "Name must be 80 characters or fewer"),
    email: z
      .string()
      .trim()
      .min(1, "Enter your email address")
      .regex(EMAIL_PATTERN, "Enter a valid email address"),
    password: z
      .string()
      .min(8, "Use at least 8 characters")
      .max(72, "Password must be 72 characters or fewer"),
    confirmPassword: z.string().min(1, "Confirm your password"),
    acceptTerms: z.boolean(),
    ageDeclared: z.boolean(),
  })
  .refine(({ password, confirmPassword }) => password === confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  })
  .refine(({ acceptTerms }) => acceptTerms === true, {
    message: "You must agree to the Terms of Service and Privacy Policy.",
    path: ["acceptTerms"],
  })
  .refine(({ ageDeclared }) => ageDeclared === true, {
    message: "You must confirm that you are 18 years of age or older.",
    path: ["ageDeclared"],
  });

export type RegisterInput = z.infer<typeof registerSchema>;

export const forgotPasswordSchema = z.object({
  email: z
    .string()
    .trim()
    .min(1, "Enter your email address")
    .regex(EMAIL_PATTERN, "Enter a valid email address"),
});

export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;

export const resetPasswordSchema = z
  .object({
    newPassword: z
      .string()
      .min(8, "Use at least 8 characters")
      .max(72, "Password must be 72 characters or fewer"),
    confirmPassword: z.string().min(1, "Confirm your password"),
  })
  .refine(({ newPassword, confirmPassword }) => newPassword === confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;

// All user-facing auth copy lives here, never inlined at a call site.
export const AUTH_COPY = {
  invalidCredentials: "Incorrect email or password.",
  rateLimited: "Too many attempts. Please wait a few minutes and try again.",
  ssoRequired:
    "Your organization requires single sign-on. Continue with your SSO provider.",
  network: "We couldn't reach the server. Check your connection and try again.",
  unexpected: "Something went wrong. Please try again.",
  configMissing: "Sign-in is temporarily unavailable. Please try again later.",
  emailInUse: "An account with this email already exists.",
  registerConfigMissing:
    "Account creation is temporarily unavailable. Please try again later.",
  resetLinkSent: "If that email exists, a reset link was sent.",
  invalidResetToken: "This reset link is invalid or has expired.",
} as const;

// Second-factor entry: a 6-digit authenticator code or a recovery code
// ("xxxxx-xxxxx"). The backend decides which; this only keeps it well-formed.
export const mfaCodeSchema = z.object({
  code: z.string().trim().min(6, "Enter your 6-digit code").max(16, "That code is too long"),
});

export type MfaCodeInput = z.infer<typeof mfaCodeSchema>;

export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, "Enter your current password"),
    newPassword: z
      .string()
      .min(8, "Use at least 8 characters")
      .max(72, "Password must be 72 characters or fewer"),
    confirmPassword: z.string().min(1, "Confirm your new password"),
  })
  .refine(({ newPassword, confirmPassword }) => newPassword === confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
