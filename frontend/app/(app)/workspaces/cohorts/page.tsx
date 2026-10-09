import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { FolderGit2, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { requireAccess } from "@/lib/server/features";
import { getMyPermissions } from "@/lib/server/permissions";
import { FEATURES } from "@/lib/features";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { getCohorts } from "@/lib/workspace/cohort-server";
import { getBatches } from "@/lib/server/batches";
import { AssignmentList } from "@/components/workspace/cohort/assignment-list";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Cohorts",
  description: "GitLab-backed class projects whose teams are workspaces.",
};

export default async function CohortsPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.PROJECTS.MANAGE)) redirect(ROUTES.WORKSPACES);

  const [cohorts, batches] = await Promise.all([getCohorts(), getBatches()]);
  const batchNameById = Object.fromEntries(batches.map((b) => [b.id, b.name]));

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Cohorts</h1>
          <p className="text-muted-foreground">
            {cohorts.length} cohort{cohorts.length === 1 ? "" : "s"}
          </p>
        </div>
        <Button asChild>
          <Link href={ROUTES.WORKSPACES_COHORTS_NEW}>
            <Plus /> New cohort
          </Link>
        </Button>
      </header>

      {cohorts.length === 0 ? (
        <div className="empty-state mt-10">
          <FolderGit2 aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No cohorts yet</p>
          <p className="text-sm text-muted-foreground">Create one, then publish it so teams provision real GitLab repos.</p>
        </div>
      ) : (
        <div className="mt-8">
          <AssignmentList assignments={cohorts} batchNameById={batchNameById} />
        </div>
      )}
    </main>
  );
}
