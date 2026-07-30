import Link from "next/link";
import { notFound } from "next/navigation";
import { Clock, CheckCircle2, Brain } from "lucide-react";
import { apiGet } from "@/lib/server/api";
import { cn } from "@/lib/utils";
import { findCourseBySlug, getCourses, getCourseTree, getCourseProgress, getEnrollments, getMyCheckProgress, getMyReflection, getMyLessonNote } from "@/lib/server/courses";
import { getMyFeedback } from "@/lib/server/feedback";
import { getRevisionPlan } from "@/lib/server/revision-plan";
import { getDueCards } from "@/lib/server/srs";
import { getModuleLab } from "@/lib/server/labs";
import { renderModuleMarkdown } from "@/lib/courses/markdown";
import { ModuleGateProvider } from "@/components/courses/module-gate-provider";
import { HighlightProvider } from "@/components/highlights/highlight-provider";
import { getHighlightsForSource } from "@/lib/server/highlights";
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
import { ModuleSystemDesign } from "@/components/courses/module-system-design";
import { RevisionPlanCard } from "@/components/revision-plan/revision-plan-card";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string; moduleId: string }>;
}

interface ModuleContent {
  module_id: string;
  presigned_url?: string;
}

async function getModuleContent(moduleId: string): Promise<ModuleContent | null> {
  try {
    return await apiGet<ModuleContent>(`/api/modules/${moduleId}/content`);
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  return { title: `Learn ${slug} — MindForge` };
}

export default async function ModuleLearnPage({ params }: Props) {
  const { slug, moduleId } = await params;

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments().catch(() => [])]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const [tree, progress, content, dueRevisions] = await Promise.all([
    getCourseTree(course.id),
    getCourseProgress(course.id).catch(() => null),
    getModuleContent(moduleId),
    getDueCards().catch(() => ({ cards: [], total: 0 })),
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
  const revisionPlan = courseComplete ? await getRevisionPlan(course.id).catch(() => null) : null;

  const notes = currentModule.type === "notes" && currentModule.content_body
    ? renderModuleMarkdown(currentModule.content_body)
    : null;

  const requiredCheckIds = notes
    ? notes.segments.flatMap((s) => (s.type === "knowledge-check" ? s.questions.map((q) => q.id) : []))
    : [];
  const passedCheckIds = requiredCheckIds.length > 0 ? await getMyCheckProgress(moduleId).catch(() => []) : [];
  const initialReflection = notes ? await getMyReflection(moduleId).catch(() => null) : null;
  const initialNote = notes ? await getMyLessonNote(moduleId).catch(() => null) : null;
  const initialHighlights = notes
    ? await getHighlightsForSource("lesson", moduleId).catch(() => [])
    : [];
  // Just needs "is there at least one active connection" — the same
  // GET /api/mcp-connections Settings → Integrations already calls.
  const hasAIConnection = notes
    ? await apiGet<{ id: string }[] | null>("/api/mcp-connections")
        .then((c) => Boolean(c?.length))
        .catch(() => false)
    : false;

  const moduleLab = currentModule.type === "notes" ? await getModuleLab(moduleId) : null;
  // system_design no longer needs the wide/no-rail treatment: its default
  // view is a compact guidance card like any other module, and the
  // whiteboard opens in its own fixed-position overlay that already escapes
  // this page's layout — so it gets the same right rail (progress bar,
  // badges, Mark as Complete, next module) as every other module type.
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
      {dueRevisions.total > 0 && (
        <Link href={ROUTES.REVIEW}>
          <Badge className="badge-warning" variant="outline">
            <Brain aria-hidden className="mr-1 h-3 w-3" />
            {dueRevisions.total} due for revision
          </Badge>
        </Link>
      )}
    </>
  );

  return (
    <ModuleGateProvider initialPassedIds={passedCheckIds} requiredIds={requiredCheckIds}>
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

        {/* eslint-disable-next-line no-restricted-syntax -- nested content column inside a custom sidebar split, not the page's top-level shell; no .page-header exists here so py-* is this column's only vertical spacing */}
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
              <HighlightProvider initialHighlights={initialHighlights} sourceId={moduleId} sourceType="lesson">
                <ModuleNotes
                  hasAIConnection={hasAIConnection}
                  highlights={initialHighlights}
                  initialCompleted={moduleProgress?.status === "completed"}
                  initialNote={initialNote}
                  initialReflection={initialReflection}
                  initialSession={moduleLab?.initialSession ?? null}
                  lab={moduleLab?.lab ?? null}
                  lessonUrl={ROUTES.courseLearnModule(slug, moduleId)}
                  moduleId={moduleId}
                  segments={notes.segments}
                  title={currentModule.title}
                />
              </HighlightProvider>
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
            {currentModule.type === "system_design" && (
              <ModuleSystemDesign
                contentBody={currentModule.content_body ?? null}
                moduleId={moduleId}
                title={currentModule.title}
              />
            )}
            {!content?.presigned_url && currentModule.type !== "notes" && currentModule.type !== "assessment" && currentModule.type !== "lab" && currentModule.type !== "system_design" && (
              <div className="empty-state py-16">
                <p className="text-sm text-muted-foreground">Content is not available yet.</p>
              </div>
            )}

            {courseComplete && <RevisionPlanCard courseId={course.id} plan={revisionPlan} />}

            <ModuleNavFooter courseSlug={slug} nextModule={nextModule} prevModule={prevModule} />
          </article>

          {!isWideLayout && (
            <ModuleProgressRail>
              <CourseProgressBar completed={completedCount} total={totalCount} />
              <div className="flex flex-wrap items-center gap-2">{moduleMeta}</div>
              {(currentModule.type === "notes" || currentModule.type === "system_design") && (
                <ModuleCompleteButton
                  initialCompleted={moduleProgress?.status === "completed"}
                  moduleId={moduleId}
                />
              )}
              {/* Next-module navigation lives once, in <ModuleNavFooter> at the
                  bottom of the article (alongside Previous) — do not duplicate
                  it here in the rail. */}
              {notes && (
                <div className="min-h-0 flex-1 overflow-y-auto">
                  <ModuleToc entries={notes.toc} />
                </div>
              )}
            </ModuleProgressRail>
          )}
        </div>
      </main>
    </div>
    </ModuleGateProvider>
  );
}
