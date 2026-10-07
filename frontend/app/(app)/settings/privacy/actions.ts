"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import { apiGet, apiAction, type ActionResult } from "@/lib/server/api";
import { revalidatePath } from "next/cache";
import ROUTES from "@/lib/routes";

export interface Nominee {
  name: string;
  relationship: string;
  contact: string;
}

export interface PrivacySettingsData {
  ai_consent: boolean;
  ai_consent_at: string | null;
  nominee: Nominee | null;
}

export interface NomineeState {
  error?: string;
  saved?: boolean;
}

export async function exportMyDataAction(): Promise<ActionResult<Record<string, unknown>>> {
  try {
    const data = await apiGet<Record<string, unknown>>("/api/privacy/export");
    return { ok: true, data };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not export your data." };
  }
}

// Mirrors app/actions/logout-action.ts's cookie-clearing — deletion already
// killed the session server-side (session_version bump), this just drops
// the now-invalid cookies from the browser too.
export async function deleteMyAccountAction(password: string): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/privacy/delete-account", { password });
  if (result.error) return result;

  const store = await cookies();
  store.delete("access_token");
  store.delete("refresh_token");
  store.delete("csrf_token");

  redirect(ROUTES.HOME);
}

export async function setAiConsentAction(consent: boolean): Promise<ActionResult<PrivacySettingsData>> {
  const result = await apiAction<PrivacySettingsData>("PUT", "/api/privacy/ai-consent", { consent });
  if (!result.error) revalidatePath(ROUTES.SETTINGS_PRIVACY);
  return result;
}

export async function saveNomineeAction(_previous: NomineeState, formData: FormData): Promise<NomineeState> {
  const field = (key: string) => (formData.get(key) ?? "").toString().trim();
  const nominee = { name: field("name"), relationship: field("relationship"), contact: field("contact") };
  const result = await apiAction<PrivacySettingsData>("PUT", "/api/privacy/nominee", { nominee });
  if (result.error) return { error: result.error };
  revalidatePath(ROUTES.SETTINGS_PRIVACY);
  return { saved: true };
}
