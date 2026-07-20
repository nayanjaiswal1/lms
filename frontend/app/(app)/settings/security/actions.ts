"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { WebAuthnCreationOptions } from "@/lib/webauthn";
import ROUTES from "@/lib/routes";

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
