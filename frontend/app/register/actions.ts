"use server";

import { redirect } from "next/navigation";

import { AUTH_COPY, registerSchema } from "@/lib/validation/auth";
import ROUTES from "@/lib/routes";
import { baseURL } from "@/lib/server/api";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";

export interface RegisterState {
  error?: string;
  fieldErrors?: {
    name?: string;
    email?: string;
    password?: string;
    confirmPassword?: string;
    acceptTerms?: string;
  };
}

function getError(body: unknown): string | undefined {
  if (!body || typeof body !== "object") return undefined;
  const error = (body as Record<string, unknown>).error;
  return typeof error === "string" && error.length > 0 ? error : undefined;
}

// The backend wraps every field-validation response in the same literal
// "validation failed" placeholder — the real reason (e.g. a breached-password
// rejection from ValidatePassword) lives in `fields`, keyed by backend field name.
function getFields(body: unknown): Record<string, string> | undefined {
  if (!body || typeof body !== "object") return undefined;
  const fields = (body as Record<string, unknown>).fields;
  return fields && typeof fields === "object" ? (fields as Record<string, string>) : undefined;
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
    acceptTerms: formData.get("acceptTerms") === "true",
  });

  if (!parsed.success) {
    const fields = parsed.error.flatten().fieldErrors;
    return {
      fieldErrors: {
        name: fields.name?.[0],
        email: fields.email?.[0],
        password: fields.password?.[0],
        confirmPassword: fields.confirmPassword?.[0],
        acceptTerms: fields.acceptTerms?.[0],
      },
    };
  }

  try {
    void baseURL();
  } catch {
    return { error: AUTH_COPY.registerConfigMissing };
  }

  let response: Response;
  let body: unknown;
  try {
    const result = await authFetchWithCookies("/api/auth/register", {
      name: parsed.data.name,
      email: parsed.data.email,
      password: parsed.data.password,
      accept_terms: parsed.data.acceptTerms,
    });
    response = result.response;
    body = result.body;
  } catch {
    return { error: AUTH_COPY.network };
  }

  if (!response.ok) {
    if (response.status === 409) return { error: AUTH_COPY.emailInUse };
    if (response.status === 429) return { error: AUTH_COPY.rateLimited };
    const fields = getFields(body);
    if (fields) {
      return {
        fieldErrors: {
          name: fields.name,
          email: fields.email,
          password: fields.password,
          acceptTerms: fields.accept_terms,
        },
      };
    }
    return { error: getError(body) ?? AUTH_COPY.unexpected };
  }

  const data = body && typeof body === "object" ? (body as Record<string, unknown>).data : undefined;
  const devToken = data && typeof data === "object" ? (data as Record<string, unknown>).dev_token : undefined;
  const encodedEmail = encodeURIComponent(parsed.data.email);

  if (typeof devToken === "string" && devToken.length > 0) {
    redirect(`${ROUTES.VERIFY_EMAIL}?email=${encodedEmail}&token=${encodeURIComponent(devToken)}`);
  }

  redirect(`${ROUTES.VERIFY_EMAIL}?email=${encodedEmail}`);
}
