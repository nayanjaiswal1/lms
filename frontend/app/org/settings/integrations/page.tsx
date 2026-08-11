import type { Metadata } from "next";
import { redirect, notFound } from "next/navigation";
import { apiGet } from "@/lib/server/api";
import { GitlabInstallationManager, type GitlabInstallationStatus, type GitlabOrgConfig } from "@/components/settings/gitlab-installation-manager";
import { getOrgAIConnectorConfig } from "@/lib/orgs/server";
import { AIConnectorToggleForm } from "@/app/org/settings/integrations/ai-connector-toggle-form";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { getCurrentOrgId } from "@/lib/server/claims";

export const metadata: Metadata = {
  title: "Integrations — Organisation Settings",
};


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
  const myPerms = await getMyPermissions();
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ORG)) {
    notFound();
  }

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
