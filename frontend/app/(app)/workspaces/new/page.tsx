import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { Breadcrumb } from "@/components/shared/breadcrumb";
import { CreateProjectForm } from "@/components/workspace/create-project-form";
import { getMyPermissions } from "@/lib/server/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "New Workspace",
};

export default async function NewWorkspacePage() {
  const permissions = await getMyPermissions();
  if (!permissions.includes(PERMISSIONS.PROJECTS.CREATE)) redirect(ROUTES.WORKSPACES);

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Workspaces", href: ROUTES.WORKSPACES }, { label: "New" }]} />
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="section-title">New workspace</h1>
        <p className="text-muted-foreground">You&apos;ll become the owner — invite a manager once the team forms.</p>
      </header>
      <CreateProjectForm />
    </main>
  );
}
