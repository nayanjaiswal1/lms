"use server";

import { redirect } from "next/navigation";
import ROUTES from "@/lib/routes";

export interface VerifyEmailState {
  error?: string;
}

export async function verifyEmailAction(
  _prev: VerifyEmailState,
  formData: FormData,
): Promise<VerifyEmailState> {
  const token = (formData.get("token") ?? "").toString().trim();
  if (!token) return { error: "Enter the verification code from your email." };

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return { error: "Verification is temporarily unavailable. Please try again later." };

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/auth/verify-email`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token }),
      cache: "no-store",
    });
  } catch {
    return { error: "We couldn't reach the server. Check your connection and try again." };
  }

  if (!response.ok) {
    const body: unknown = await response.json().catch(() => null);
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
