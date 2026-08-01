import "server-only";
import { cookies } from "next/headers";

/**
 * Reads the access token's payload **without verifying its signature**.
 *
 * This is deliberate and safe only for the narrow use it exists for: telling
 * the UI which org the user is currently in, and which role to render controls
 * for. The Go API re-derives both on every request (RequireOrgMember resolves
 * the org from the database, RequireOrgRole the role) and rejects anything the
 * caller is not entitled to, so nothing here decides access — it only decides
 * what gets drawn.
 *
 * The decode used to be copy-pasted into a dozen pages, which made the
 * unverified-JWT pattern look like an ordinary way to read a claim and left no
 * single place to state the caveat. It lives here now, and `no-restricted-syntax`
 * in eslint.config.mjs blocks new hand-rolled copies.
 *
 * Never branch on these values for authorization — in a server action or route
 * handler, ask the API instead.
 */
export interface UnverifiedAccessClaims {
  user_id?: string;
  org_id?: string;
  org_role?: string;
}

export async function getUnverifiedClaims(): Promise<UnverifiedAccessClaims | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    return JSON.parse(
      // eslint-disable-next-line no-restricted-syntax -- this is the single sanctioned decode the ban points callers at; the caveat about never using these values for authorization is documented on this module.
      Buffer.from(parts[1], "base64url").toString(),
    ) as UnverifiedAccessClaims;
  } catch {
    return null;
  }
}

/** The org the user is currently acting in, for UI scoping only. */
export async function getCurrentOrgId(): Promise<string | null> {
  return (await getUnverifiedClaims())?.org_id ?? null;
}

/** The user's role in the active org, for UI gating only. */
export async function getCurrentOrgRole(): Promise<string | null> {
  return (await getUnverifiedClaims())?.org_role ?? null;
}
