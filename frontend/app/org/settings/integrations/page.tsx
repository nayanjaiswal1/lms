import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { apiGet } from "@/lib/server/api";
import { GitlabInstallationManager, type GitlabInstallationStatus, type GitlabOrgConfig } from "@/components/settings/gitlab-installation-manager";
import { getOrgAIConnectorConfig } from "@/lib/orgs/server";
import { AIConnectorToggleForm } from "@/app/org/settings/integrations/ai-connector-toggle-form";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Integrations — Organisation Settings",
};

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

// GET /api/gitlab/org-config 404s (ErrNotFound) for an org that's never set
// a policy — normalized to the column's own default here rather than
// throwing to error.tsx, matching org/settings/page.tsx's fetchOrg
// try/catch pattern.
async function fetchGitlabOrgConfig(): Promise<GitlabOrgConfig> {
  try {
    return await apiGet<GitlabOrgConfig>("/api/gitlab/org-config");
  } catch {
    return { allow_project_override: true };
  }
}

export default async function OrgIntegrationsPage() {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [installations, orgConfig, aiConnectorConfig] = await Promise.all([
    apiGet<GitlabInstallationStatus[]>("/api/gitlab/installations"),
    fetchGitlabOrgConfig(),
    getOrgAIConnectorConfig(orgId),
  ]);

  return (
    <div className="space-y-6">
      <div className="card-base p-6">
        <h2 className="subsection-title text-foreground mb-4">AI Connector</h2>
        <AIConnectorToggleForm config={aiConnectorConfig} orgId={orgId} />
      </div>
      <GitlabInstallationManager installations={installations} orgConfig={orgConfig} />
    </div>
  );
}
