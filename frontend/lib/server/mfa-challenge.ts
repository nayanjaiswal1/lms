import "server-only";

import { cookies } from "next/headers";
import { asString, getField } from "@/lib/server/login-destination";
import ROUTES from "@/lib/routes";

// The backend's first-factor success can answer with an MFA challenge instead
// of a session. The token rides in a short-lived httpOnly cookie (never the
// URL) scoped to the /login pages that complete the second step.
const COOKIE = "mfa_challenge";
const TTL_SECONDS = 300;

export interface MfaChallenge {
  challenge: string;
  enroll: boolean;
  next?: string;
}

// Returns the second-step route when `body` is an MFA challenge response
// (and stores the challenge), or null when it carries a normal session.
export async function startMfaStep(body: unknown, next?: string | null): Promise<string | null> {
  const data = getField(body, "data");
  const challenge = asString(getField(data, "challenge"));
  if (getField(data, "mfa_required") !== true || !challenge) return null;

  const value: MfaChallenge = {
    challenge,
    enroll: getField(data, "mfa_enroll_required") === true,
    next: next ?? undefined,
  };
  (await cookies()).set(COOKIE, JSON.stringify(value), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: ROUTES.LOGIN,
    maxAge: TTL_SECONDS,
  });
  return ROUTES.LOGIN_MFA;
}

export async function readMfaChallenge(): Promise<MfaChallenge | null> {
  const raw = (await cookies()).get(COOKIE)?.value;
  if (!raw) return null;
  try {
    const parsed: unknown = JSON.parse(raw);
    const challenge = asString(getField(parsed, "challenge"));
    if (!challenge) return null;
    return {
      challenge,
      enroll: getField(parsed, "enroll") === true,
      next: asString(getField(parsed, "next")),
    };
  } catch {
    return null;
  }
}

export async function clearMfaChallenge(): Promise<void> {
  (await cookies()).delete({ name: COOKIE, path: ROUTES.LOGIN });
}
