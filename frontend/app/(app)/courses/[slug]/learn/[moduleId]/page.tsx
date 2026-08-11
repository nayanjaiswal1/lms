import { Fragment } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Clock, CheckCircle2, Brain, Terminal } from "lucide-react";
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
import { LessonLabProvider } from "@/components/courses/lesson-lab-provider";
import { LessonLabHero } from "@/components/courses/lesson-lab-hero";
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
import { LessonNotes } from "@/components/courses/lesson-notes";
import { ModuleAssessment } from "@/components/courses/module-assessment";
import { ModuleLab } from "@/components/courses/module-lab";
import { ModuleSystemDesign } from "@/components/courses/module-system-design";
import { LessonMoreMenu } from "@/components/courses/lesson-more-menu";
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
  return { title: `Learn ${slug}` };
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
  // True before the student has ever started a lab attached to this lesson —
  // the Launch Lab hero (badges, title, button) then renders in the right
  // rail below instead of inline in the lesson body (see ModuleNotes).
  const hasUnstartedLab = Boolean(moduleLab?.lab) && !moduleLab?.initialSession;
  // Whether the rail should keep hosting <LessonLabHero> at all — not just
  // "not started" (hasUnstartedLab) but also mid-provisioning: once the
  // student clicks Launch Lab the session isn't running yet (isLabOpen is
  // still false, since isLabSessionActive excludes "provisioning"), so the
  // layout hasn't switched to the wide no-rail treatment yet either. Gating
  // this on hasUnstartedLab alone made the rail's End Lab / provisioning
  // status disappear the instant the student clicked Launch Lab, with
  // nothing replacing it until isLabOpen flips true — this keeps
  // LessonLabHero mounted through that gap so its own provisioning-card
  // branch has somewhere to render. Once running/paused, isLabOpen goes
  // true and the rail is hidden by the wide-layout switch anyway (see
  // isWideLayout below), so this never doubles up with the inline
  // ModuleNotes copy's "End Lab" header.
  const showLabInRail = Boolean(moduleLab?.lab) && !isLabOpen;
  // system_design no longer needs the wide/no-rail treatment: its default
  // view is a compact guidance card like any other module, and the
  // whiteboard opens in its own fixed-position overlay that already escapes
  // this page's layout — so it gets the same right rail (progress bar,
  // badges) and bottom nav footer (Mark as Complete, next module) as every
  // other module type.
  const isWideLayout = currentModule.type === "lab" || isLabOpen;

  const moduleMeta = (
    <>
      <Badge className="gap-1.5 rounded-full border-primary/20 bg-accent px-2.5 py-1 font-mono text-sm capitalize text-primary" variant="outline">
        {MODULE_TYPE_LABEL[currentModule.type] ?? currentModule.type}
      </Badge>
      {currentModule.estimated_minutes && (
        <Badge className="gap-1.5 rounded-full px-2.5 py-1 font-mono text-sm" variant="secondary">
          <Clock aria-hidden className="h-3.5 w-3.5" />{currentModule.estimated_minutes} min
        </Badge>
      )}
      {moduleProgress?.status === "completed" && (
        <Badge className="badge-success gap-1.5 rounded-full px-2.5 py-1 font-mono text-sm" variant="outline">
          <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />Completed
        </Badge>
      )}
      {dueRevisions.total > 0 && (
        <Link href={ROUTES.REVIEW}>
          <Badge className="badge-warning gap-1.5 rounded-full px-2.5 py-1 font-mono text-sm" variant="outline">
            <Brain aria-hidden className="h-3.5 w-3.5" />
            {dueRevisions.total} due for revision
          </Badge>
        </Link>
      )}
      {/* Lab type moved here from <LessonLabHero>'s own badge row — that row
          was cramming 4 badges into the w-80 rail card and wrapping.
          Duration stays out of here deliberately: this row already has the
          lesson's own estimated_minutes clock badge, and the lab's
          max_duration is a different number that happens to coincide with
          it in most fixtures — two identical clock badges side by side
          reads as a duplicate, not two facts. Duration, task count, and
          points all stay on the lab card itself. */}
      {hasUnstartedLab && moduleLab?.lab && (
        <Badge className="gap-1.5 rounded-full border-primary/20 bg-accent px-2.5 py-1 font-mono text-sm capitalize text-primary" variant="outline">
          <Terminal aria-hidden className="h-3.5 w-3.5" />{moduleLab.lab.lab_type}
        </Badge>
      )}
    </>
  );

  // LessonLabProvider needs a non-null lab, so it can't wrap unconditionally
  // — Fragment is a drop-in stand-in with the same `{children}` shape for
  // modules with no attached lab, letting the JSX below wrap once instead of
  // duplicating the whole article+rail block per branch.
  const LabProviderWrapper = moduleLab?.lab
    ? function LabProviderWrapper({ children }: { children: React.ReactNode }) {
        return (
          <LessonLabProvider initialSession={moduleLab.initialSession ?? null} lab={moduleLab.lab}>
            {children}
          </LessonLabProvider>
        );
      }
    : Fragment;

  return (
    <ModuleGateProvider
      initialPassedIds={passedCheckIds}
      labCompleted={moduleLab?.initialSession?.session.status === "completed"}
      labRequired={Boolean(moduleLab?.lab)}
      requiredIds={requiredCheckIds}
    >
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

        {/* No gap-* / justify-* on this row: article's own mx-auto (below)
            splits 100% of the row's leftover width evenly as its left/right
            margins, so article ends up centered between the nav edge and
            the rail, with the rail flush to the row's right edge (mirrors
            the nav sidebar pinned to the left — no dead strip past the
            rail). A gap-* here would sit on top of that auto-margin split
            rather than replace it, making the article-to-rail side bigger
            than the nav-to-article side by the gap amount — exactly the
            lopsided spacing this replaced. No effect on the isWideLayout
            case (article alone, no max-w cap, already fills the row).
            No px-* here (unlike .page-container elsewhere): this column
            already sits inside <main class="app-content">'s own edge
            padding, so adding a second edge gutter here would just push the
            rail further from the page edge for no reason. */}
        {/* eslint-disable-next-line no-restricted-syntax -- nested content column inside a custom sidebar split, not the page's top-level shell; no .page-header exists here so py-* is this column's only vertical spacing, and .page-container's px-* would double up with app-content's own edge padding */}
        <div className="mx-auto max-w-7xl flex items-start py-6 lg:py-8">
        <LabProviderWrapper>
          <article className={cn("min-w-0 flex-1", !isWideLayout && "mx-auto max-w-3xl")}>
            {!isWideLayout && (
              <div className="mb-2 flex items-start justify-between gap-3">
                <h2 className="min-w-0 flex-1 text-2xl font-bold tracking-tight">{currentModule.title}</h2>
                <LessonMoreMenu
                  courseSlug={slug}
                  fallbackModuleId={(prevModule ?? nextModule)?.id ?? null}
                  isSelfCourse={course.kind === "self"}
                  moduleId={moduleId}
                  moduleTitle={currentModule.title}
                />
              </div>
            )}
            <div className="mb-6 flex flex-wrap items-center gap-2">{moduleMeta}</div>

            {currentModule.type === "video" && content?.presigned_url && (
              <ModuleVideo
                initialPositionSeconds={moduleProgress?.last_position_seconds}
                moduleId={moduleId}
                presignedUrl={content.presigned_url}
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
                  initialReflection={initialReflection}
                  initialSession={moduleLab?.initialSession ?? null}
                  lab={moduleLab?.lab ?? null}
                  moduleId={moduleId}
                  segments={notes.segments}
                />
              </HighlightProvider>
            )}
            {currentModule.type === "assessment" && currentModule.assessment_id && (
              <ModuleAssessment
                assessmentId={currentModule.assessment_id}
                moduleId={moduleId}
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

            <ModuleNavFooter
              completeButton={
                (currentModule.type === "notes" || currentModule.type === "system_design") ? (
                  <ModuleCompleteButton
                    initialCompleted={moduleProgress?.status === "completed"}
                    moduleId={moduleId}
                  />
                ) : null
              }
              courseSlug={slug}
              nextModule={nextModule}
              prevModule={prevModule}
            />
          </article>

          {!isWideLayout && (
            <ModuleProgressRail>
              <CourseProgressBar completed={completedCount} total={totalCount} />
              {/* Mark as Complete lives once, at the bottom of the article via
                  <ModuleNavFooter>'s completeButton slot — do not duplicate it
                  here in the rail. Delete lesson / Report moved to
                  <LessonMoreMenu> next to the title above. */}
              {firstRunnableLanguage && <LessonCompilerToggle language={firstRunnableLanguage} />}
              {notes && <LessonNotes initialContent={initialNote} moduleId={moduleId} />}
              {/* Launch Lab card (and its provisioning/End Lab states) for a
                  lesson's attached lab — lives here instead of inline in the
                  lesson body (see ModuleNotes) so it doesn't interrupt the
                  reading flow. showLabInRail (not hasUnstartedLab) keeps it
                  mounted through the provisioning gap — see that variable's
                  comment above. */}
              {showLabInRail && <LessonLabHero pageTitle={currentModule.title} />}
              {notes && (
                <div className="min-h-0 flex-1 overflow-y-auto">
                  <ModuleToc entries={notes.toc} />
                </div>
              )}
            </ModuleProgressRail>
          )}
        </LabProviderWrapper>

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
