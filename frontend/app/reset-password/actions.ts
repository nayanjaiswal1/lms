"use server";

import { redirect } from "next/navigation";

import { resetPasswordSchema, AUTH_COPY } from "@/lib/validation/auth";
import { apiAction } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export interface ResetPasswordState {
  error?: string;
  fieldErrors?: { newPassword?: string; confirmPassword?: string };
}

export async function resetPasswordAction(
  _prev: ResetPasswordState,
  formData: FormData,
): Promise<ResetPasswordState> {
  const token = (formData.get("token") ?? "").toString();
  if (!token) return { error: AUTH_COPY.invalidResetToken };

  const parsed = resetPasswordSchema.safeParse({
    newPassword: (formData.get("newPassword") ?? "").toString(),
    confirmPassword: (formData.get("confirmPassword") ?? "").toString(),
  });

  if (!parsed.success) {
    const fields = parsed.error.flatten().fieldErrors;
    return {
      fieldErrors: {
        newPassword: fields.newPassword?.[0],
        confirmPassword: fields.confirmPassword?.[0],
      },
    };
  }

  const result = await apiAction("POST", "/api/auth/reset-password", {
    token,
    new_password: parsed.data.newPassword,
  });

  if (!result.ok) {
    return { error: result.error ?? AUTH_COPY.invalidResetToken };
  }

  redirect(`${ROUTES.LOGIN}?reset=1`);
}
