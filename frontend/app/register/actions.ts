"use server";

import { redirect } from "next/navigation";

import { AUTH_COPY, registerSchema } from "@/lib/validation/auth";
import ROUTES from "@/lib/routes";

export interface RegisterState {
  error?: string;
  fieldErrors?: {
    name?: string;
    email?: string;
    password?: string;
    confirmPassword?: string;
  };
}

function getError(body: unknown): string | undefined {
  if (!body || typeof body !== "object") return undefined;
  const error = (body as Record<string, unknown>).error;
  return typeof error === "string" && error.length > 0 ? error : undefined;
}

export async function registerAction(
  _previous: RegisterState,
  formData: FormData,
): Promise<RegisterState> {
  const parsed = registerSchema.safeParse({
    name: (formData.get("name") ?? "").toString(),
    email: (formData.get("email") ?? "").toString(),
    password: (formData.get("password") ?? "").toString(),
    confirmPassword: (formData.get("confirmPassword") ?? "").toString(),
  });

  if (!parsed.success) {
    const fields = parsed.error.flatten().fieldErrors;
    return {
      fieldErrors: {
        name: fields.name?.[0],
        email: fields.email?.[0],
        password: fields.password?.[0],
        confirmPassword: fields.confirmPassword?.[0],
      },
    };
  }

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return { error: AUTH_COPY.registerConfigMissing };

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: parsed.data.name,
        email: parsed.data.email,
        password: parsed.data.password,
      }),
      cache: "no-store",
    });
  } catch {
    return { error: AUTH_COPY.network };
  }

  if (!response.ok) {
    const body: unknown = await response.json().catch(() => null);
    if (response.status === 409) return { error: AUTH_COPY.emailInUse };
    if (response.status === 429) return { error: AUTH_COPY.rateLimited };
    return { error: getError(body) ?? AUTH_COPY.unexpected };
  }

  const body: unknown = await response.json().catch(() => null);
  const data = body && typeof body === "object" ? (body as Record<string, unknown>).data : undefined;
  const devToken = data && typeof data === "object" ? (data as Record<string, unknown>).dev_token : undefined;
  const encodedEmail = encodeURIComponent(parsed.data.email);

  if (typeof devToken === "string" && devToken.length > 0) {
    redirect(`${ROUTES.VERIFY_EMAIL}?email=${encodedEmail}&token=${encodeURIComponent(devToken)}`);
  }

  redirect(`${ROUTES.VERIFY_EMAIL}?email=${encodedEmail}`);
}
