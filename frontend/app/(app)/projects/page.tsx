import type { Metadata } from "next";
import Link from "next/link";
import { FolderGit2, Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { requireAccess } from "@/lib/server/features";
import { getOrgRole } from "@/lib/server/auth";
import { FEATURES } from "@/lib/features";
import { getProjectAssignments, listMyProjects } from "@/lib/projects/server";
import { getBatches } from "@/lib/server/batches";
import { PROVISION_STATUS_LABEL, PROVISION_VARIANT } from "@/lib/constants";
import { AssignmentList } from "@/components/projects/assignment-list";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Projects",
  description: "GitLab-backed project assignments and team provisioning.",
};

export default async function ProjectsPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);

  // Matches the backend's own gate on GET /api/projects/assignments
  // (middleware.RequireOrgRole(RoleAdmin, RoleInstructor) in
  // internal/gitlab/routes.go) — anyone else only ever sees their own teams.
  const orgRole = await getOrgRole();
  const canManage = orgRole === "admin" || orgRole === "instructor";

  if (canManage) {
    const [assignments, batches] = await Promise.all([getProjectAssignments(), getBatches()]);
    const batchNameById = Object.fromEntries(batches.map((b) => [b.id, b.name]));

    return (
      <main className="page-container">
        <header className="page-header">
          <div className="flex flex-col gap-1">
            <h1 className="page-title">Projects</h1>
            <p className="text-muted-foreground">
              {assignments.length} project assignment{assignments.length === 1 ? "" : "s"}
            </p>
          </div>
          <Button asChild>
            <Link href={ROUTES.PROJECTS_NEW}>
              <Plus /> New assignment
            </Link>
          </Button>
        </header>

        {assignments.length === 0 ? (
          <div className="empty-state mt-10">
            <FolderGit2 aria-hidden className="h-10 w-10 text-muted-foreground" />
            <p className="mt-3 font-medium">No project assignments yet</p>
            <p className="text-sm text-muted-foreground">Create one, then publish it so teams provision real GitLab repos.</p>
          </div>
        ) : (
          <div className="mt-8">
            <AssignmentList assignments={assignments} batchNameById={batchNameById} />
          </div>
        )}
      </main>
    );
  }

  const projects = await listMyProjects();

  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex items-center gap-3">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10">
            <FolderGit2 aria-hidden className="h-5 w-5 text-primary" />
          </span>
          <h1 className="page-title">Projects</h1>
        </div>
      </header>
      <p className="mb-6 text-muted-foreground">Your GitLab team assignments across every batch.</p>

      {projects.length === 0 ? (
        <div className="empty-state py-16">
          <FolderGit2 aria-hidden className="empty-state-icon" />
          <p className="font-medium text-muted-foreground">No project teams yet.</p>
          <p className="text-sm text-muted-foreground">
            You&apos;ll see your team here once an instructor adds you to a project assignment.
          </p>
        </div>
      ) : (
        <div className="card-grid">
          {projects.map((p) => (
            <Link
              className="card-base card-interactive flex flex-col gap-3 p-6"
              href={ROUTES.myProject(p.team_id)}
              key={p.team_id}
            >
              <div className="flex items-start justify-between gap-2">
                <span className="text-base font-semibold">{p.team_name}</span>
                <Badge variant={PROVISION_VARIANT[p.provision_status] ?? "outline"}>
                  {PROVISION_STATUS_LABEL[p.provision_status] ?? p.provision_status}
                </Badge>
              </div>
              <p className="text-sm text-muted-foreground">{p.assignment_title}</p>
              <span className="text-xs capitalize text-muted-foreground">{p.role}</span>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}
