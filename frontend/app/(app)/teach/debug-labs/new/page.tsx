import type { Metadata } from "next";
import { NewRecipeForm } from "@/components/labs/builder/new-recipe-form";
import { getBlocks, requireLabAuthor } from "@/lib/labs/builder/server";

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
    <main className="page-container-sm flex flex-col gap-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">New debug lab</h1>
          <p className="text-sm text-muted-foreground">
            Pick the application students will debug. Faults, data and checks come next.
          </p>
        </div>
      </div>
      <div className="card-base">
        <NewRecipeForm appOptions={options} placement={placement} />
      </div>
    </main>
  );
}
