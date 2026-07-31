import Link from "next/link";
import { notFound } from "next/navigation";
import { Clock, CheckCircle2, Brain } from "lucide-react";
import { apiGet } from "@/lib/server/api";
import { cn } from "@/lib/utils";
import { findCourseBySlug, getCourses, getCourseTree, getCourseProgress, getEnrollments, getMyCheckProgress, getMyReflection, getMyLessonNote } from "@/lib/server/courses";
import { getMyFeedback } from "@/lib/server/feedback";
import { getDueCards } from "@/lib/server/srs";
import { getModuleLab } from "@/lib/server/labs";
import { isLabSessionActive } from "@/lib/labs";
import { renderModuleMarkdown } from "@/lib/courses/markdown";
import { isRunnableLanguage } from "@/lib/courses/runnable-languages";
import { LabFixedConsole } from "@/components/labs/lab-fixed-console";
import { LessonCompilerToggle } from "@/components/courses/lesson-compiler-toggle";
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

  const notes = currentModule.type === "notes" && currentModule.content_body
    ? renderModuleMarkdown(currentModule.content_body)
    : null;

  const requiredCheckIds = notes
    ? notes.segments.flatMap((s) => (s.type === "knowledge-check" ? s.questions.map((q) => q.id) : []))
    : [];
  // First runnable-language snippet in the lesson, if any — surfaced as a
  // standalone scratch compiler in the right rail (LessonCompilerToggle) so
  // a reader doesn't have to scroll back to a specific code block to try
  // the language. Inline per-block runners (LessonCodeRunner) are unaffected.
  const firstRunnableLanguage = notes
    ? notes.segments.find((s): s is Extract<typeof s, { type: "code" }> => s.type === "code" && isRunnableLanguage(s.language))
        ?.language ?? null
    : null;
  const passedCheckIds = requiredCheckIds.length > 0 ? await getMyCheckProgress(moduleId).catch(() => []) : [];
  const initialReflection = notes ? await getMyReflection(moduleId).catch(() => null) : null;
  const initialNote = notes ? await getMyLessonNote(moduleId).catch(() => null) : null;
  const initialHighlights = notes
    ? await getHighlightsForSource("lesson", moduleId).catch(() => [])
    : [];

  const moduleLab = currentModule.type === "notes" ? await getModuleLab(moduleId) : null;
  // True once a lab linked to this notes lesson is actually running —
  // ModuleNotes then splits into notes + workspace panes (see
  // LessonLabWorkspacePane), so this page gives up the same space a
  // type==="lab" module gets: no max-w column, no right rail, no left nav.
  const isLabOpen = Boolean(
    moduleLab?.initialSession && isLabSessionActive(moduleLab.initialSession.session.status),
  );
  // system_design no longer needs the wide/no-rail treatment: its default
  // view is a compact guidance card like any other module, and the
  // whiteboard opens in its own fixed-position overlay that already escapes
  // this page's layout — so it gets the same right rail (progress bar,
  // badges, Mark as Complete, next module) as every other module type.
  const isWideLayout = currentModule.type === "lab" || isLabOpen;

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

      {/* Collapsed while the lab split is open — the workspace pane needs
          the room, and the left nav is one click away via End Lab. */}
      {!isLabOpen && (
        <CourseSidebarRail course={tree} currentModuleId={moduleId} isEnrolled={isEnrolled} progress={progressModules} />
      )}

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
              <HighlightProvider
                initialHighlights={initialHighlights}
                lessonUrl={ROUTES.courseLearnModule(slug, moduleId)}
                moduleTitle={currentModule.title}
                sourceId={moduleId}
                sourceType="lesson"
              >
                <ModuleNotes
                  highlights={initialHighlights}
                  initialCompleted={moduleProgress?.status === "completed"}
                  initialNote={initialNote}
                  initialReflection={initialReflection}
                  initialSession={moduleLab?.initialSession ?? null}
                  lab={moduleLab?.lab ?? null}
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
              {firstRunnableLanguage && <LessonCompilerToggle language={firstRunnableLanguage} />}
              {notes && (
                <div className="min-h-0 flex-1 overflow-y-auto">
                  <ModuleToc entries={notes.toc} />
                </div>
              )}
            </ModuleProgressRail>
          )}

          {/* The rail above is hidden while the lab split is open, so "On
              this page" relocates to the same draggable bottom dock a
              console-layout lab's terminal already uses. Skipped for
              console-layout labs specifically — they're already using that
              dock for the terminal, and stacking two fixed panels would
              overlap (ponytail: narrow edge case, not worth a second dock). */}
          {isLabOpen && notes && notes.toc.length > 0 && moduleLab?.lab.layout !== "console" && (
            <LabFixedConsole title="On this page">
              <ModuleToc entries={notes.toc} />
            </LabFixedConsole>
          )}
        </div>
      </main>
    </div>
    </ModuleGateProvider>
  );
}
