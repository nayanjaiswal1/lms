"use server";

import { redirect } from "next/navigation";
import { AUTH_COPY, mfaCodeSchema } from "@/lib/validation/auth";
import { baseURL, type ActionResult } from "@/lib/server/api";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";
import { asString, getField, resolveLoginDestination } from "@/lib/server/login-destination";
import { clearMfaChallenge, readMfaChallenge } from "@/lib/server/mfa-challenge";
import ROUTES from "@/lib/routes";
import { safeNextPath } from "@/lib/utils";

export interface MfaVerifyState {
  error?: string;
}

// The backend answers a wrong code with exactly this message; any other 401
// means the challenge itself expired or was already spent.
const INVALID_CODE_MESSAGE = "Invalid code.";

function failure(status: number, body: unknown): string {
  if (status === 429) return AUTH_COPY.rateLimited;
  return asString(getField(body, "error")) ?? AUTH_COPY.unexpected;
}

function isExpired(status: number, body: unknown): boolean {
  return status === 401 && asString(getField(body, "error")) !== INVALID_CODE_MESSAGE;
}

export async function verifyMfaAction(
  _prev: MfaVerifyState,
  formData: FormData,
): Promise<MfaVerifyState> {
  const parsed = mfaCodeSchema.safeParse({ code: (formData.get("code") ?? "").toString() });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message };

  const challenge = await readMfaChallenge();
  if (!challenge) redirect(ROUTES.LOGIN);

  let apiUrl: string;
  try {
    apiUrl = baseURL();
  } catch {
    return { error: AUTH_COPY.configMissing };
  }

  let response: Response;
  let body: unknown;
  try {
    ({ response, body } = await authFetchWithCookies("/api/auth/mfa/verify", {
      challenge: challenge.challenge,
      code: parsed.data.code,
    }));
  } catch {
    return { error: AUTH_COPY.network };
  }

  if (!response.ok) {
    if (isExpired(response.status, body)) {
      await clearMfaChallenge();
      redirect(`${ROUTES.LOGIN}?error=mfa_expired`);
    }
    return { error: failure(response.status, body) };
  }

  await clearMfaChallenge();
  redirect(await resolveLoginDestination(apiUrl, response, body, safeNextPath(challenge.next)));
}

interface EnrollBegin {
  secret: string;
  uri: string;
}

export async function beginMfaEnrollAction(): Promise<ActionResult<EnrollBegin>> {
  const challenge = await readMfaChallenge();
  if (!challenge) return { error: "Your sign-in expired. Please sign in again.", status: 401 };
  try {
    const { response, body } = await authFetchWithCookies("/api/auth/mfa/enroll/begin", {
      challenge: challenge.challenge,
    });
    const data = getField(body, "data");
    const secret = asString(getField(data, "secret"));
    const uri = asString(getField(data, "uri"));
    if (!response.ok || !secret || !uri) {
      return { error: failure(response.status, body), status: response.status };
    }
    return { ok: true, data: { secret, uri } };
  } catch {
    return { error: AUTH_COPY.network };
  }
}

interface EnrollFinish {
  recoveryCodes: string[];
  redirectTo: string;
}

export async function finishMfaEnrollAction(code: string): Promise<ActionResult<EnrollFinish>> {
  const parsed = mfaCodeSchema.safeParse({ code });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message };

  const challenge = await readMfaChallenge();
  if (!challenge) return { error: "Your sign-in expired. Please sign in again.", status: 401 };

  try {
    const apiUrl = baseURL();
    const { response, body } = await authFetchWithCookies("/api/auth/mfa/enroll/finish", {
      challenge: challenge.challenge,
      code: parsed.data.code,
    });
    if (!response.ok) {
      if (isExpired(response.status, body)) await clearMfaChallenge();
      return { error: failure(response.status, body), status: response.status };
    }
    const codes = getField(getField(body, "data"), "recovery_codes");
    await clearMfaChallenge();
    return {
      ok: true,
      data: {
        recoveryCodes: Array.isArray(codes) ? codes.filter((c): c is string => typeof c === "string") : [],
        redirectTo: await resolveLoginDestination(apiUrl, response, body, safeNextPath(challenge.next)),
      },
    };
  } catch {
    return { error: AUTH_COPY.network };
  }
}
