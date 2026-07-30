import type { Metadata } from "next";

import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { getBatches } from "@/lib/server/batches";
import { apiGet } from "@/lib/server/api";
import { CreateAssignmentForm } from "@/components/projects/create-assignment-form";
import type { GitlabInstallationStatus } from "@/components/settings/gitlab-installation-card";

export const metadata: Metadata = {
  title: "New Project Assignment",
};

// GET /api/gitlab/org-config 404s (ErrNotFound) for an org that's never set
// a policy — normalized to the column's own default, same as
// app/org/settings/integrations/page.tsx's own fetchGitlabOrgConfig.
async function fetchAllowInstallationOverride(): Promise<boolean> {
  try {
    const cfg = await apiGet<{ allow_project_override: boolean }>("/api/gitlab/org-config");
    return cfg.allow_project_override;
  } catch {
    return true;
  }
}

export default async function NewProjectAssignmentPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const [batches, installations, allowInstallationOverride] = await Promise.all([
    getBatches(),
    apiGet<GitlabInstallationStatus[]>("/api/gitlab/installations"),
    fetchAllowInstallationOverride(),
  ]);

  return (
    <main className="page-container-sm">
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="page-title">New project assignment</h1>
        <p className="text-muted-foreground">Every team under this assignment forks the same template repo.</p>
      </header>
      <CreateAssignmentForm allowInstallationOverride={allowInstallationOverride} batches={batches} installations={installations} />
    </main>
  );
}
