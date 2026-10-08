"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { WebAuthnCreationOptions } from "@/lib/webauthn";
import ROUTES from "@/lib/routes";
import { changePasswordSchema } from "@/lib/validation/auth";

interface WebAuthnRegisterBeginResult {
  handle: string;
  options: WebAuthnCreationOptions;
}

export async function registerPasskeyBeginAction(): Promise<
  ActionResult<WebAuthnRegisterBeginResult>
> {
  return apiAction<WebAuthnRegisterBeginResult>(
    "POST",
    "/api/auth/webauthn/register/begin",
  );
}

interface WebAuthnRegisterFinishResult {
  credential: { id: string; nickname: string };
}

export async function registerPasskeyFinishAction(
  handle: string,
  nickname: string,
  credentialResponse: unknown,
): Promise<ActionResult<WebAuthnRegisterFinishResult>> {
  const result = await apiAction<WebAuthnRegisterFinishResult>(
    "POST",
    "/api/auth/webauthn/register/finish",
    { handle, nickname, response: credentialResponse },
  );
  if (result.ok) revalidatePath(ROUTES.SETTINGS_SECURITY);
  return result;
}

export async function renamePasskeyAction(
  id: string,
  nickname: string,
): Promise<ActionResult<undefined>> {
  const result = await apiAction("PATCH", `/api/auth/webauthn/credentials/${id}`, { nickname });
  if (result.ok) revalidatePath(ROUTES.SETTINGS_SECURITY);
  return result;
}

export async function deletePasskeyAction(id: string): Promise<ActionResult<undefined>> {
  const result = await apiAction("DELETE", `/api/auth/webauthn/credentials/${id}`);
  if (result.ok) revalidatePath(ROUTES.SETTINGS_SECURITY);
  return result;
}

interface MfaSetup {
  secret: string;
  uri: string;
}

export async function beginMfaSetupAction(): Promise<ActionResult<MfaSetup>> {
  return apiAction<MfaSetup>("POST", "/api/auth/mfa/setup");
}

export async function enableMfaAction(
  code: string,
): Promise<ActionResult<{ recoveryCodes: string[] }>> {
  const result = await apiAction<{ recovery_codes: string[] }>("POST", "/api/auth/mfa/enable", { code });
  if (!result.ok || !result.data) return { ...result, data: undefined, conflict: undefined };
  revalidatePath(ROUTES.SETTINGS_SECURITY);
  return { ok: true, data: { recoveryCodes: result.data.recovery_codes } };
}

export async function regenerateRecoveryCodesAction(
  code: string,
): Promise<ActionResult<{ recoveryCodes: string[] }>> {
  const result = await apiAction<{ recovery_codes: string[] }>("POST", "/api/auth/mfa/recovery-codes", { code });
  if (!result.ok || !result.data) return { ...result, data: undefined, conflict: undefined };
  revalidatePath(ROUTES.SETTINGS_SECURITY);
  return { ok: true, data: { recoveryCodes: result.data.recovery_codes } };
}

export async function disableMfaAction(code: string): Promise<ActionResult<undefined>> {
  const result = await apiAction("POST", "/api/auth/mfa/disable", { code });
  if (result.ok) revalidatePath(ROUTES.SETTINGS_SECURITY);
  return result;
}

export async function changePasswordAction(
  currentPassword: string,
  newPassword: string,
): Promise<ActionResult<undefined>> {
  const parsed = changePasswordSchema.safeParse({ currentPassword, newPassword, confirmPassword: newPassword });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message };
  // The backend revokes every session and answers with fresh cookies for this
  // one; apiAction forwards them to the browser.
  const result = await apiAction("POST", "/api/auth/change-password", {
    current_password: currentPassword,
    new_password: newPassword,
  });
  return result.ok ? { ok: true } : { error: result.error, fieldErrors: result.fieldErrors, status: result.status };
}

/** Signs out one device. Revoking the current device ends this session, so go to login. */
export async function revokeSessionAction(id: string): Promise<ActionResult<{ revoked_current: boolean }>> {
  const result = await apiAction<{ revoked_current: boolean }>("DELETE", `/api/auth/sessions/${id}`);
  if (result.ok && result.data?.revoked_current) redirect(ROUTES.LOGIN);
  if (result.ok) revalidatePath(ROUTES.SETTINGS_SECURITY);
  return result;
}
