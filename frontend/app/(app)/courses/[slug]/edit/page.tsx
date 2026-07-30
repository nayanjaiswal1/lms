import { notFound } from "next/navigation";
import Link from "next/link";
import { Plus, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getAllStudentProgress, getCourseTree, getInstructorCourseBySlug, type StudentProgressRow } from "@/lib/server/courses";
import { getWikiSpaces } from "@/lib/server/wiki";
import { ModuleEditor } from "@/components/courses/module-editor";
import { CourseDocsToggle } from "@/components/courses/course-docs-toggle";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  return { title: course ? `${course.title} — MindForge` : "Course — MindForge" };
}

export default async function InstructorCourseDetailPage({ params }: Props) {
  const { slug } = await params;
  const course = await getInstructorCourseBySlug(slug).catch(() => undefined);
  if (!course) notFound();
  const id = course.id;

  const [tree, wikiSpaces, progress] = await Promise.all([
    getCourseTree(id).catch(() => null),
    getWikiSpaces().catch(() => []),
    getAllStudentProgress(id).catch(() => [] as StudentProgressRow[]),
  ]);
  if (!tree) notFound();
  const docsSpace = wikiSpaces.find((s) => s.course_id === id) ?? null;

  const totalStudents = progress.length;
  const completed = progress.filter((r) => r.total_modules > 0 && r.completed_modules === r.total_modules).length;
  const completionPct = totalStudents > 0 ? Math.round((completed / totalStudents) * 100) : 0;

  return (
    <main className="page-container">
      <Breadcrumb items={[{ label: "Teach", href: ROUTES.TEACH }, { label: tree.title }]} />

      <div className="page-header">
        <div className="flex items-center gap-3">
          <h1 className="section-title">{tree.title}</h1>
          {tree.status !== "published" && (
            <Badge variant="secondary">{tree.status}</Badge>
          )}
        </div>
        <nav aria-label="Course management" className="flex flex-wrap items-center gap-6 text-sm">
          <Link className="font-semibold text-primary underline underline-offset-4" href={ROUTES.courseEditSettings(slug)}>
            Course settings
          </Link>
          <Link className="text-muted-foreground transition-colors hover:text-foreground" href={ROUTES.courseEditAnalytics(slug)}>
            View analytics
          </Link>
          {tree.status === "published" && (
            <Link
              className="text-muted-foreground transition-colors hover:text-foreground"
              href={ROUTES.course(tree.slug)}
              rel="noopener noreferrer"
              target="_blank"
            >
              Preview as student
            </Link>
          )}
          <CourseDocsToggle courseId={id} courseTitle={tree.title} existingSpaceSlug={docsSpace?.slug ?? null} />
        </nav>
      </div>

      <div className="flex flex-col gap-8">
        {tree.sections.length === 0 ? (
          <div className="empty-state py-16">
            <p className="text-sm text-muted-foreground">No sections yet. Add the first section to build your course.</p>
          </div>
        ) : (
          <ol aria-label="Course sections" className="flex flex-col gap-6">
            {tree.sections.map((section, si) => (
              <li className="flex flex-col gap-2" key={section.id}>
                <div className="flex-between">
                  <h2 className="section-title">
                    Section {si + 1}: {section.title}
                  </h2>
                  <span className="text-xs font-medium tracking-wide text-muted-foreground uppercase">
                    {section.modules.length} module{section.modules.length === 1 ? "" : "s"}
                  </span>
                </div>
                <div className="card-base overflow-hidden p-0">
                  {section.modules.length > 0 && (
                    <ul className="flex flex-col divide-y divide-border">
                      {section.modules.map((mod, mi) => (
                        <li className="flex items-center gap-3 px-6 py-3 text-sm" key={mod.id}>
                          <span className="w-6 shrink-0 font-mono text-xs text-muted-foreground">
                            {String(mi + 1).padStart(2, "0")}
                          </span>
                          <span className="flex-1 truncate">{mod.title}</span>
                          <span className="rounded-full border border-border px-2.5 py-0.5 text-xs capitalize text-muted-foreground">
                            {mod.type}
                          </span>
                          <span className="w-10 shrink-0 text-right text-xs text-muted-foreground">
                            {mod.estimated_minutes ? `${mod.estimated_minutes}m` : "—"}
                          </span>
                        </li>
                      ))}
                    </ul>
                  )}
                  <details className="px-6 py-3">
                    <summary className="flex cursor-pointer list-none items-center gap-1.5 text-xs font-bold text-primary hover:underline [&::-webkit-details-marker]:hidden">
                      <Plus aria-hidden className="h-3.5 w-3.5" />
                      Add module
                    </summary>
                    <div className="mt-3 rounded-lg border border-border p-4">
                      <ModuleEditor courseId={id} sectionId={section.id} />
                    </div>
                  </details>
                </div>
              </li>
            ))}
          </ol>
        )}

        <div className="card-raised flex flex-col gap-4 bg-foreground text-background sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-col gap-1">
            <div className="flex items-center gap-2 text-sm font-semibold">
              <Users aria-hidden className="h-4 w-4" />
              Student progress overview
            </div>
            <p className="text-sm text-background/70">
              {totalStudents > 0
                ? `${totalStudents} student${totalStudents === 1 ? "" : "s"} enrolled · ${completionPct}% have completed the course.`
                : "No students have enrolled yet."}
            </p>
          </div>
          <Button asChild size="sm" variant="secondary">
            <Link href={ROUTES.courseEditAnalytics(slug)}>View full analytics</Link>
          </Button>
        </div>
      </div>
    </main>
  );
}
