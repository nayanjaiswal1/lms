"use server";

import { apiAction, type ActionResult } from "@/lib/server/api";

export interface AuthorizeDecisionInput {
  client_id: string;
  redirect_uri: string;
  scope: string;
  state: string;
  code_challenge: string;
}

interface RedirectResult {
  redirect_url: string;
}

export async function approveMcpAuthorizeAction(
  input: AuthorizeDecisionInput,
): Promise<ActionResult<RedirectResult>> {
  return apiAction<RedirectResult>("POST", "/oauth/authorize/approve", input);
}

export async function denyMcpAuthorizeAction(
  input: AuthorizeDecisionInput,
): Promise<ActionResult<RedirectResult>> {
  return apiAction<RedirectResult>("POST", "/oauth/authorize/deny", input);
}
