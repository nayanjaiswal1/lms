"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

export async function revokeMcpConnectionAction(connectionId: string): Promise<ActionResult<undefined>> {
  const result = await apiAction("DELETE", `/api/mcp-connections/${connectionId}`);
  if (result.ok) revalidatePath(ROUTES.SETTINGS_INTEGRATIONS);
  return result;
}

// ─── GitLab: personal connection (any org member) ────────────────────────────

export async function disconnectGitlabAction(): Promise<ActionResult<undefined>> {
  const result = await apiAction("POST", "/api/gitlab/disconnect");
  if (result.ok) revalidatePath(ROUTES.SETTINGS_INTEGRATIONS);
  return result;
}

// ─── GitLab: org installation pool (admin-only) ───────────────────────────────

export interface GitlabInstallationPutResponse {
  // Present when auth_kind="pat": the install completed synchronously.
  id?: string;
  name?: string;
  is_default?: boolean;
  connected?: boolean;
  base_url?: string;
  tier?: string;
  auth_kind?: string;
  status?: string;
  gitlab_username?: string;
  has_oauth_app?: boolean;
  // Present when auth_kind="oauth": redirect the admin's browser here next.
  authorize_url?: string;
  pending?: boolean;
}

export interface InstallGitlabPATInput {
  name: string;
  baseUrl: string;
  personalAccessToken: string;
  oauthClientId?: string;
  oauthClientSecret?: string;
}

export async function createGitlabInstallationPATAction(input: InstallGitlabPATInput): Promise<ActionResult<GitlabInstallationPutResponse>> {
  const result = await apiAction<GitlabInstallationPutResponse>("POST", "/api/gitlab/installations", {
    name: input.name,
    auth_kind: "pat",
    base_url: input.baseUrl,
    personal_access_token: input.personalAccessToken,
    oauth_client_id: input.oauthClientId ?? "",
    oauth_client_secret: input.oauthClientSecret ?? "",
  });
  if (result.ok) revalidatePath(ROUTES.ORG_SETTINGS_INTEGRATIONS);
  return result;
}

export interface StartGitlabInstallOAuthInput {
  name: string;
  baseUrl: string;
  oauthClientId: string;
  oauthClientSecret?: string;
}

export async function startGitlabInstallOAuthAction(input: StartGitlabInstallOAuthInput): Promise<ActionResult<GitlabInstallationPutResponse>> {
  return apiAction<GitlabInstallationPutResponse>("POST", "/api/gitlab/installations", {
    name: input.name,
    auth_kind: "oauth",
    base_url: input.baseUrl,
    oauth_client_id: input.oauthClientId,
    oauth_client_secret: input.oauthClientSecret ?? "",
  });
}

export async function verifyGitlabInstallationAction(installationId: string): Promise<ActionResult<GitlabInstallationPutResponse>> {
  const result = await apiAction<GitlabInstallationPutResponse>("POST", `/api/gitlab/installations/${installationId}/verify`);
  if (result.ok) revalidatePath(ROUTES.ORG_SETTINGS_INTEGRATIONS);
  return result;
}

export async function setDefaultGitlabInstallationAction(installationId: string): Promise<ActionResult<GitlabInstallationPutResponse>> {
  const result = await apiAction<GitlabInstallationPutResponse>("POST", `/api/gitlab/installations/${installationId}/set-default`);
  if (result.ok) revalidatePath(ROUTES.ORG_SETTINGS_INTEGRATIONS);
  return result;
}

export async function disconnectGitlabInstallationAction(installationId: string): Promise<ActionResult<undefined>> {
  const result = await apiAction("DELETE", `/api/gitlab/installations/${installationId}`);
  if (result.ok) revalidatePath(ROUTES.ORG_SETTINGS_INTEGRATIONS);
  return result;
}

export async function setGitlabOrgConfigAction(allowProjectOverride: boolean): Promise<ActionResult<{ allow_project_override: boolean }>> {
  const result = await apiAction<{ allow_project_override: boolean }>("PUT", "/api/gitlab/org-config", {
    allow_project_override: allowProjectOverride,
  });
  if (result.ok) revalidatePath(ROUTES.ORG_SETTINGS_INTEGRATIONS);
  return result;
}
