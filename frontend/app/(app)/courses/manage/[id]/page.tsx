import { notFound } from "next/navigation";
import Link from "next/link";
import { Plus } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { getCourseTree } from "@/lib/server/courses";
import { ModuleEditor } from "@/components/instructor/module-editor";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const tree = await getCourseTree(id).catch(() => null);
  return { title: tree ? `${tree.title} — MindForge` : "Course — MindForge" };
}

export default async function InstructorCourseDetailPage({ params }: Props) {
  const { id } = await params;
  const tree = await getCourseTree(id).catch(() => null);
  if (!tree) notFound();

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <h1 className="page-title">{tree.title}</h1>
          <Badge variant={tree.status === "published" ? "default" : "secondary"}>
            {tree.status}
          </Badge>
        </div>
        <div className="flex items-center gap-4">
          <Link className="text-sm text-primary hover:underline" href={ROUTES.manageCourseEdit(id)}>
            Edit course
          </Link>
          <Link className="text-sm text-primary hover:underline" href={ROUTES.manageCourseAnalytics(id)}>
            View analytics
          </Link>
        </div>
      </div>

      <div className="flex flex-col gap-8">
        {tree.sections.length === 0 ? (
          <div className="empty-state py-16">
            <p className="text-sm text-muted-foreground">No sections yet. Add the first section to build your course.</p>
          </div>
        ) : (
          <ol aria-label="Course sections" className="flex flex-col gap-6">
            {tree.sections.map((section, si) => (
              <li className="card-base p-6" key={section.id}>
                <h2 className="section-title mb-4">
                  Section {si + 1}: {section.title}
                </h2>
                {section.modules.length > 0 && (
                  <ul className="mb-4 flex flex-col gap-2">
                    {section.modules.map((mod, mi) => (
                      <li className="flex items-center gap-3 rounded-md border border-border px-3 py-2 text-sm" key={mod.id}>
                        <span className="w-5 text-muted-foreground">{mi + 1}.</span>
                        <span className="flex-1">{mod.title}</span>
                        <span className="rounded bg-muted px-1.5 py-0.5 text-xs capitalize text-muted-foreground">{mod.type}</span>
                        {mod.estimated_minutes && (
                          <span className="text-xs text-muted-foreground">{mod.estimated_minutes}m</span>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
                <details className="mt-2">
                  <summary className="flex cursor-pointer items-center gap-1 text-sm text-primary hover:underline">
                    <Plus aria-hidden className="h-4 w-4" />
                    Add module
                  </summary>
                  <div className="mt-3 rounded-lg border border-border p-4">
                    <ModuleEditor courseId={id} sectionId={section.id} />
                  </div>
                </details>
              </li>
            ))}
          </ol>
        )}
      </div>
    </main>
  );
}
