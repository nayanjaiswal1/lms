"use server";

import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";
import { baseURL } from "@/lib/server/api";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";

export interface VerifyEmailState {
  error?: string;
}

export async function verifyEmailAction(
  _prev: VerifyEmailState,
  formData: FormData,
): Promise<VerifyEmailState> {
  const token = (formData.get("token") ?? "").toString().trim();
  if (!token) return { error: "Enter the verification code from your email." };

  try {
    void baseURL();
  } catch {
    return { error: "Verification is temporarily unavailable. Please try again later." };
  }

  let response: Response;
  let body: unknown;
  try {
    const result = await authFetchWithCookies("/api/auth/verify-email", { token });
    response = result.response;
    body = result.body;
  } catch {
    return { error: "We couldn't reach the server. Check your connection and try again." };
  }

  if (!response.ok) {
    const apiError =
      body && typeof body === "object"
        ? (body as Record<string, unknown>).error
        : undefined;
    return {
      error:
        typeof apiError === "string" && apiError.length > 0
          ? apiError
          : "Invalid or expired verification code.",
    };
  }

  redirect(`${ROUTES.LOGIN}?verified=1`);
}
