import type { Metadata } from "next";

import ROUTES from "@/lib/routes";
import { requireAccess } from "@/lib/server/features";
import { FEATURES } from "@/lib/features";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { CreateRequirementForm } from "@/components/projects/create-requirement-form";

export const metadata: Metadata = {
  title: "New Project Requirement",
};

export default async function NewRequirementPage() {
  await requireAccess(FEATURES.GITLAB_INTEGRATION);

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ label: "Requirements", href: ROUTES.PROJECTS_REQUIREMENTS }, { label: "New" }]} />
      <header className="mb-6 flex flex-col gap-1">
        <h1 className="section-title">New project requirement</h1>
        <p className="text-muted-foreground">Posted as a draft — publish it once you&apos;re ready to open applications.</p>
      </header>
      <CreateRequirementForm />
    </main>
  );
}
