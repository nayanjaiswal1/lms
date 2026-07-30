"use server";

import { forgotPasswordSchema, AUTH_COPY } from "@/lib/validation/auth";
import { apiAction } from "@/lib/server/api";

export interface ForgotPasswordState {
  sent?: boolean;
  error?: string;
  fieldErrors?: { email?: string };
}

export async function forgotPasswordAction(
  _prev: ForgotPasswordState,
  formData: FormData,
): Promise<ForgotPasswordState> {
  const parsed = forgotPasswordSchema.safeParse({
    email: (formData.get("email") ?? "").toString(),
  });

  if (!parsed.success) {
    const fields = parsed.error.flatten().fieldErrors;
    return { fieldErrors: { email: fields.email?.[0] } };
  }

  const result = await apiAction("POST", "/api/auth/forgot-password", parsed.data);
  // The backend always returns 200 with a generic message regardless of
  // whether the email exists, to avoid leaking account existence — the only
  // failure worth surfacing here is a genuine network/config error.
  if (!result.ok) {
    return { error: result.error ?? AUTH_COPY.unexpected };
  }

  return { sent: true };
}
