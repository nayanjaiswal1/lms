import Link from "next/link";
import { notFound } from "next/navigation";
import { Clock, CheckCircle2, ArrowRight } from "lucide-react";
import { authHeaders } from "@/lib/server/api";
import { cn } from "@/lib/utils";
import { getCourses, getCourseTree, getCourseProgress, getEnrollments } from "@/lib/server/courses";
import { getMyFeedback } from "@/lib/server/feedback";
import { getModuleLab } from "@/lib/server/labs";
import { renderModuleMarkdown } from "@/lib/courses/markdown";
import { MODULE_TYPE_LABEL } from "@/lib/courses/module-types";
import { computeCompletion } from "@/lib/courses/progress";
import { Badge } from "@/components/ui/badge";
import { CourseCompletionPrompt } from "@/components/feedback/course-completion-prompt";
import { CourseSidebarRail } from "@/components/courses/course-sidebar-rail";
import { CourseSidebarDrawer } from "@/components/courses/course-sidebar-drawer";
import { CourseProgressBar } from "@/components/courses/course-progress-bar";
import { ModuleCompleteButton } from "@/components/courses/module-complete-button";
import { ModuleProgressRail } from "@/components/courses/module-progress-rail";
import { ModuleToc } from "@/components/courses/module-toc";
import { ModuleNavFooter } from "@/components/courses/module-nav-footer";
import { ModuleVideo } from "@/components/courses/module-video";
import { ModulePDF } from "@/components/courses/module-pdf";
import { ModuleNotes } from "@/components/courses/module-notes";
import { ModuleAssessment } from "@/components/courses/module-assessment";
import { ModuleLab } from "@/components/courses/module-lab";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string; moduleId: string }>;
}

interface ModuleContent {
  module_id: string;
  presigned_url?: string;
}

async function getModuleContent(moduleId: string): Promise<ModuleContent | null> {
  const api = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!api) return null;
  const headers = await authHeaders();
  const res = await fetch(`${api}/api/modules/${moduleId}/content`, { headers, cache: "no-store" });
  if (!res.ok) return null;
  const body: { data: ModuleContent } = await res.json();
  return body.data;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  return { title: `Learn ${slug} — MindForge` };
}

export default async function ModuleLearnPage({ params }: Props) {
  const { slug, moduleId } = await params;

  const courses = await getCourses();
  const course = courses.find((c) => c.slug === slug);
  if (!course) notFound();

  const [tree, progress, content, enrollments] = await Promise.all([
    getCourseTree(course.id),
    getCourseProgress(course.id).catch(() => null),
    getModuleContent(moduleId),
    getEnrollments().catch(() => []),
  ]);

  const allModules = tree.sections.flatMap((s) => s.modules);
  const currentIndex = allModules.findIndex((m) => m.id === moduleId);
  const currentModule = allModules[currentIndex];
  if (!currentModule) notFound();

  const prevModule = currentIndex > 0 ? allModules[currentIndex - 1] : null;
  const nextModule = currentIndex < allModules.length - 1 ? allModules[currentIndex + 1] : null;

  const isEnrolled = enrollments.some((e) => e.course_id === course.id);
  const progressModules = progress?.modules ?? [];
  const moduleProgress = progressModules.find((p) => p.module_id === moduleId);
  const { completed: completedCount, total: totalCount } = computeCompletion(allModules.map((m) => m.id), progressModules);

  const courseComplete = isEnrolled && totalCount > 0 && completedCount === totalCount;
  const myCourseFeedback = courseComplete
    ? await getMyFeedback("course", course.id).catch(() => null)
    : null;

  const notes = currentModule.type === "notes" && currentModule.content_body
    ? renderModuleMarkdown(currentModule.content_body)
    : null;

  const moduleLab = currentModule.type === "notes" ? await getModuleLab(moduleId) : null;
  const isWideLayout = currentModule.type === "lab";

  const moduleMeta = (
    <>
      <Badge className="capitalize" variant="outline">
        {MODULE_TYPE_LABEL[currentModule.type] ?? currentModule.type}
      </Badge>
      {currentModule.estimated_minutes && (
        <Badge variant="secondary">
          <Clock aria-hidden className="mr-1 h-3 w-3" />{currentModule.estimated_minutes} min
        </Badge>
      )}
      {moduleProgress?.status === "completed" && (
        <Badge className="badge-success" variant="outline">
          <CheckCircle2 aria-hidden className="mr-1 h-3 w-3" />Completed
        </Badge>
      )}
    </>
  );

  return (
    <div className="flex flex-col items-start gap-6 lg:flex-row">
      {courseComplete && !myCourseFeedback && <CourseCompletionPrompt courseId={course.id} />}

      <CourseSidebarRail course={tree} currentModuleId={moduleId} isEnrolled={isEnrolled} progress={progressModules} />

      <main className="min-w-0 flex-1">
        <CourseSidebarDrawer
          course={tree}
          currentModuleId={moduleId}
          currentModuleTitle={currentModule.title}
          isEnrolled={isEnrolled}
          progress={progressModules}
        />

        <div className="page-container flex items-start gap-6 py-6 lg:py-8 xl:gap-10">
          <article className={cn("min-w-0 flex-1", !isWideLayout && "max-w-3xl")}>
            <div className="mb-6 flex flex-wrap items-center gap-2 xl:hidden">
              {moduleMeta}
            </div>

            {currentModule.type === "video" && content?.presigned_url && (
              <ModuleVideo
                initialPositionSeconds={moduleProgress?.last_position_seconds}
                moduleId={moduleId}
                presignedUrl={content.presigned_url}
                title={currentModule.title}
              />
            )}
            {currentModule.type === "pdf" && content?.presigned_url && (
              <ModulePDF
                moduleId={moduleId}
                presignedUrl={content.presigned_url}
                title={currentModule.title}
              />
            )}
            {currentModule.type === "notes" && notes && (
              <ModuleNotes
                initialCompleted={moduleProgress?.status === "completed"}
                initialSession={moduleLab?.initialSession ?? null}
                lab={moduleLab?.lab ?? null}
                moduleId={moduleId}
                segments={notes.segments}
                title={currentModule.title}
              />
            )}
            {currentModule.type === "assessment" && currentModule.assessment_id && (
              <ModuleAssessment
                assessmentId={currentModule.assessment_id}
                moduleId={moduleId}
                title={currentModule.title}
              />
            )}
            {currentModule.type === "lab" && (
              <ModuleLab moduleId={moduleId} title={currentModule.title} />
            )}
            {!content?.presigned_url && currentModule.type !== "notes" && currentModule.type !== "assessment" && currentModule.type !== "lab" && (
              <div className="empty-state py-16">
                <p className="text-sm text-muted-foreground">Content is not available yet.</p>
              </div>
            )}

            <ModuleNavFooter courseSlug={slug} nextModule={nextModule} prevModule={prevModule} />
          </article>

          {!isWideLayout && (
            <ModuleProgressRail>
              <CourseProgressBar completed={completedCount} total={totalCount} />
              <div className="flex flex-wrap items-center gap-2">{moduleMeta}</div>
              {currentModule.type === "notes" && notes && (
                <ModuleCompleteButton
                  initialCompleted={moduleProgress?.status === "completed"}
                  moduleId={moduleId}
                />
              )}
              {notes && (
                <div className="min-h-0 flex-1 overflow-y-auto">
                  <ModuleToc entries={notes.toc} />
                </div>
              )}
              {/* Only shown when there's no TOC to fill the rail — on notes
                  pages the TOC already claims the remaining space (and pushing
                  this below it would just clip it off, invisible). */}
              {!notes && nextModule && (
                <Link
                  className="mt-auto flex items-center justify-between gap-2 rounded-lg border border-border bg-card px-4 py-3 text-sm transition-colors duration-fast hover:bg-muted"
                  href={ROUTES.courseLearnModule(slug, nextModule.id)}
                >
                  <span className="flex min-w-0 flex-col">
                    <span className="text-xs text-muted-foreground">Next</span>
                    <span className="line-clamp-1 font-medium text-foreground">{nextModule.title}</span>
                  </span>
                  <ArrowRight aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                </Link>
              )}
            </ModuleProgressRail>
          )}
        </div>
      </main>
    </div>
  );
}
