import type { Metadata } from "next";
import Link from "next/link";
import { ClipboardList, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { listRequirements } from "@/lib/projects/server";
import { RequirementList } from "@/components/projects/requirement-list";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Project Requirements",
  description: "Post project briefs and review student applications.",
};

export default async function RequirementsPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);
  const requirements = await listRequirements();

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-1">
          <h1 className="page-title">Project requirements</h1>
          <p className="text-muted-foreground">
            {requirements.length} requirement{requirements.length === 1 ? "" : "s"}
          </p>
        </div>
        <Button asChild>
          <Link href={ROUTES.PROJECTS_REQUIREMENTS_NEW}>
            <Plus /> New requirement
          </Link>
        </Button>
      </header>

      {requirements.length === 0 ? (
        <div className="empty-state mt-10">
          <ClipboardList aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No requirements yet</p>
          <p className="text-sm text-muted-foreground">Post a project brief, then publish it to open the board.</p>
        </div>
      ) : (
        <div className="mt-8">
          <RequirementList requirements={requirements} />
        </div>
      )}
    </main>
  );
}
