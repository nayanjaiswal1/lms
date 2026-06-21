"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import ROUTES from "@/lib/routes";

export interface CreateOrgState {
  error?: string;
  fieldErrors?: {
    name?: string;
    slug?: string;
    description?: string;
  };
}

const SLUG_RE = /^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/;

function validateFields(
  name: string,
  slug: string,
): CreateOrgState["fieldErrors"] | null {
  const errors: CreateOrgState["fieldErrors"] = {};

  if (name.length < 2 || name.length > 100) {
    errors.name = "Name must be between 2 and 100 characters.";
  }
  if (!SLUG_RE.test(slug)) {
    errors.slug =
      "Slug must be 3–63 characters, lowercase letters, numbers, and hyphens only.";
  }

  return Object.keys(errors).length > 0 ? errors : null;
}

function getField(body: unknown, key: string): unknown {
  if (body && typeof body === "object") {
    return (body as Record<string, unknown>)[key];
  }
  return undefined;
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

export async function createOrgAction(
  _prev: CreateOrgState,
  formData: FormData,
): Promise<CreateOrgState> {
  const name = (formData.get("name") ?? "").toString().trim();
  const slug = (formData.get("slug") ?? "").toString().trim();
  const description = (formData.get("description") ?? "").toString().trim();
  const idempotencyKey =
    (formData.get("idempotency_key") ?? "").toString() ||
    `${Date.now()}-${Math.random().toString(36).slice(2)}`;

  const fieldErrors = validateFields(name, slug);
  if (fieldErrors) {
    return { fieldErrors };
  }

  const apiBase = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL ?? "";
  const store = await cookies();
  const accessToken = store.get("access_token")?.value ?? "";
  const csrfToken = store.get("csrf_token")?.value ?? "";

  let response: Response;
  try {
    response = await fetch(`${apiBase}/api/orgs`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Cookie: `access_token=${accessToken}; csrf_token=${csrfToken}`,
        "X-CSRF-Token": csrfToken,
        "Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify({
        name,
        slug,
        description: description || null,
      }),
      cache: "no-store",
    });
  } catch {
    return { error: "Network error. Please check your connection and try again." };
  }

  const body: unknown = await response.json().catch(() => null);

  if (!response.ok) {
    if (response.status === 409) {
      const code = asString(getField(body, "code"));
      if (code === "slug_taken") {
        return { fieldErrors: { slug: "This slug is already taken." } };
      }
    }
    const msg = asString(getField(body, "error"));
    return { error: msg ?? "Something went wrong. Please try again." };
  }

  await forwardSetCookies(response.headers);
  redirect(ROUTES.ORG_SETUP);
}
