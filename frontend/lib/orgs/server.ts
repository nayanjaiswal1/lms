import "server-only";

import { apiGet } from "@/lib/server/api";
import type {
  Org,
  OrgSummary,
  OnboardingState,
  MemberPage,
  InvitePage,
  AuditLogPage,
  Domain,
  OrgAuthConfig,
} from "@/lib/orgs/types";

export async function getMyOrgs(): Promise<OrgSummary[]> {
  return apiGet<OrgSummary[]>("/api/orgs/me");
}

export async function getOrgById(orgId: string): Promise<Org> {
  return apiGet<Org>(`/api/orgs/${orgId}`);
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
