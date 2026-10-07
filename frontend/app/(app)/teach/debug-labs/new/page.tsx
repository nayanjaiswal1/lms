import type { Metadata } from "next";
import { BackLink } from "@/components/labs/builder/back-link";
import { NewRecipeForm } from "@/components/labs/builder/new-recipe-form";
import { getBlocks, requireLabAuthor } from "@/lib/labs/builder/server";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "New debug lab" };

interface NewDebugLabPageProps {
  searchParams: Promise<{ course?: string; section?: string }>;
}

// Steps 1-2 of the wizard (stack + base app) create the recipe; "Create debug
// lab here" in the course editor passes ?course=&section= as the placement.
export default async function NewDebugLabPage({ searchParams }: NewDebugLabPageProps) {
  await requireLabAuthor();
  const [{ course, section }, apps] = await Promise.all([searchParams, getBlocks({ kind: "app" })]);
  const options = apps.map((a) => ({ value: a.latest_version_id, label: `${a.stack} · ${a.title} (${a.latest_version})` }));
  const placement = course && section ? { course_id: course, section_id: section } : null;

  return (
    <main className="page-container-sm flex flex-col gap-2">
      <BackLink href={ROUTES.LAB_BUILDER} label="All debug labs" />
      <h1 className="page-title py-4">New debug lab</h1>
      <NewRecipeForm appOptions={options} placement={placement} />
    </main>
  );
}
