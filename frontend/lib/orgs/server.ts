import "server-only";

import { apiGet } from "@/lib/server/api";
import { getOrgId } from "@/lib/server/batches";
import { getCurrentOrgId } from "@/lib/server/claims";
import type {
  Org,
  OrgSummary,
  OnboardingState,
  MemberPage,
  InvitePage,
  AuditLogPage,
  Domain,
  OrgAuthConfig,
  OrgAIConnectorConfig,
} from "@/lib/orgs/types";

export async function getMyOrgs(): Promise<OrgSummary[]> {
  return apiGet<OrgSummary[]>("/api/orgs/me");
}

export async function getOrgById(orgId: string): Promise<Org> {
  return apiGet<Org>(`/api/orgs/${orgId}`);
}

/** The current session's org_type, or null if unset/unauthenticated — feeds TerminologyProvider. */
export async function getCurrentOrgType(): Promise<string | null> {
  const orgId = await getOrgId();
  if (!orgId) return null;
  const org = await getOrgById(orgId).catch(() => null);
  return org?.org_type ?? null;
}

export interface OrgBranding {
  name: string | null;
  logo_url: string | null;
}

/** The current org's white-label name/logo override, or nulls if unset/unauthenticated — feeds BrandingProvider. */
export async function getCurrentOrgBranding(): Promise<OrgBranding> {
  const orgId = await getCurrentOrgId();
  if (!orgId) return { name: null, logo_url: null };
  const org = await getOrgById(orgId).catch(() => null);
  return { name: org?.name ?? null, logo_url: org?.logo_url ?? null };
}

export async function getOnboardingState(orgId: string): Promise<OnboardingState> {
  return apiGet<OnboardingState>(`/api/orgs/${orgId}/onboarding`);
}

export async function getOrgMembers(
  orgId: string,
  cursor?: string,
): Promise<MemberPage> {
  const params = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
  return apiGet<MemberPage>(`/api/orgs/${orgId}/members${params}`);
}

export async function getOrgInvites(
  orgId: string,
  cursor?: string,
): Promise<InvitePage> {
  const params = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
  return apiGet<InvitePage>(`/api/orgs/${orgId}/invites${params}`);
}

export async function getAuditLogs(
  orgId: string,
  cursor?: string,
): Promise<AuditLogPage> {
  const params = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
  return apiGet<AuditLogPage>(`/api/orgs/${orgId}/audit-logs${params}`);
}

export async function getOrgDomains(orgId: string): Promise<Domain[]> {
  return apiGet<Domain[]>(`/api/orgs/${orgId}/domains`);
}

export async function getOrgAuthConfig(orgId: string): Promise<OrgAuthConfig> {
  return apiGet<OrgAuthConfig>(`/api/orgs/${orgId}/auth-config`);
}

export async function getOrgAIConnectorConfig(orgId: string): Promise<OrgAIConnectorConfig> {
  return apiGet<OrgAIConnectorConfig>(`/api/orgs/${orgId}/ai-connector-config`);
}
