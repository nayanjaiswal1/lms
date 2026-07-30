import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { FolderTree } from "lucide-react";

import { getBatches, getOrgId, getOrgMembersAll } from "@/lib/server/batches";
import { getCohortGroups, buildCohortTree, flattenCohortOptions } from "@/lib/server/cohorts";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";
import { CohortGroupTree } from "@/components/cohorts/cohort-group-tree";
import { CohortGroupsPanel } from "@/app/(app)/cohort-groups/cohort-groups-panel";
import { BatchesPanel } from "@/app/(app)/batches/batches-panel";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Batches",
  description: "Batches and the optional group hierarchy above them (e.g. Class 10 → Section A).",
};

export default async function CohortGroupsPage() {
  const orgId = await getOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [groups, batches, orgType, orgMembers] = await Promise.all([
    getCohortGroups(),
    getBatches(),
    getCurrentOrgType(),
    getOrgMembersAll(orgId).catch(() => []),
  ]);
  const tree = buildCohortTree(groups);
  const options = flattenCohortOptions(tree);
  const t = resolveTerminology(orgType);

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">{t.classPlural}</h1>
          <p className="text-muted-foreground">
            Drag a {t.class_.toLowerCase()} onto a group to move it, or open one to edit or manage it directly.
          </p>
        </div>
        <div className="flex gap-2">
          <BatchesPanel />
          <CohortGroupsPanel groups={groups} />
        </div>
      </header>

      <section>
        {batches.length === 0 && groups.length === 0 ? (
          <div className="empty-state">
            <FolderTree aria-hidden className="h-10 w-10 text-muted-foreground" />
            <p className="mt-3 font-medium">No {t.classPlural.toLowerCase()} yet</p>
            <p className="text-sm text-muted-foreground">
              Create a {t.class_.toLowerCase()}, then group it under a hierarchy if you need one.
            </p>
          </div>
        ) : (
          <div className="card-base p-4">
            <CohortGroupTree allGroups={groups} batches={batches} mode="manage" options={options} orgMembers={orgMembers} roots={tree} />
          </div>
        )}
      </section>
    </main>
  );
}
