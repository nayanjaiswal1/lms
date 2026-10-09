import type { Metadata } from "next";
import { redirect } from "next/navigation";

import ROUTES from "@/lib/routes";
import { requireAccess } from "@/lib/server/features";
import { getMyPermissions } from "@/lib/server/permissions";
import { FEATURES } from "@/lib/features";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getBatches } from "@/lib/server/batches";
import { apiGet } from "@/lib/server/api";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { CreateAssignmentForm } from "@/components/workspace/cohort/create-assignment-form";
import type { GitlabInstallationOption } from "@/lib/workspace/types";

export const metadata: Metadata = {
  title: "New Cohort",
};

// GET /api/gitlab/org-config 404s for an org that has never set a policy;
// normalized to the column's own default.
async function fetchAllowInstallationOverride(): Promise<boolean> {
  try {
    const cfg = await apiGet<{ allow_project_override: boolean }>("/api/gitlab/org-config");
    return cfg.allow_project_override;
  } catch {
    return true;
  }
}

export default async function NewCohortPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.PROJECTS.MANAGE)) redirect(ROUTES.WORKSPACES);

  const [batches, installations, allowInstallationOverride] = await Promise.all([
    getBatches(),
    apiGet<GitlabInstallationOption[]>("/api/gitlab/installations"),
    fetchAllowInstallationOverride(),
  ]);

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Cohorts", href: ROUTES.WORKSPACES_COHORTS }, { label: "New" }]} />
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="section-title">New cohort</h1>
        <p className="text-muted-foreground">Every team under this cohort forks the same template repo.</p>
      </header>
      <CreateAssignmentForm allowInstallationOverride={allowInstallationOverride} batches={batches} installations={installations} />
    </main>
  );
}
