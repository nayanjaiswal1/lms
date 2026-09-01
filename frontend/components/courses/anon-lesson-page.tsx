"use client";

import { useEffect, useState } from "react";
import { Clock, CheckCircle2, Lock } from "lucide-react";
import Link from "next/link";
import { getAnonProgress, setAnonModuleCompleted } from "@/lib/courses/anon-progress";
import { renderModuleMarkdown } from "@/lib/courses/markdown";
import { computeCompletion } from "@/lib/courses/progress";
import { MODULE_TYPE_LABEL } from "@/lib/courses/module-types";
import type { CourseTree, ModuleProgress } from "@/lib/server/courses";
import { CourseSidebarRail } from "@/components/courses/course-sidebar-rail";
import { CourseSidebarDrawer } from "@/components/courses/course-sidebar-drawer";
import { CourseProgressBar } from "@/components/courses/course-progress-bar";
import { ModuleProgressRail } from "@/components/courses/module-progress-rail";
import { ModuleToc } from "@/components/courses/module-toc";
import { ModuleNavFooter } from "@/components/courses/module-nav-footer";
import { AnonModuleNotes } from "@/components/courses/anon-module-notes";
import { AnonModuleCompleteButton } from "@/components/courses/anon-module-complete-button";
import { AnonLessonNotes } from "@/components/courses/anon-lesson-notes";
import { AnonCourseBanner } from "@/components/courses/anon-course-banner";
import { Badge } from "@/components/ui/badge";
import ROUTES from "@/lib/routes";

interface AnonLessonPageProps {
  course: CourseTree;
  currentModuleId: string;
}

// Module types docs/anonymous.md scopes anonymous reading to — everything
// else (video/pdf/assessment/lab) needs a signed URL or a session tied to a
// real user, so it prompts sign-in instead.
const READABLE_TYPES = new Set(["notes", "system_design"]);

// Anonymous rendering of the course-learn page (docs/anonymous.md) — the
// unauthenticated branch of app/(app)/courses/[slug]/learn/[moduleId]/page.tsx.
// Reuses every purely-presentational piece of the authenticated page
// (sidebar rail/drawer, progress bar/rail, TOC, nav footer) driven by a
// ModuleProgress[] array computed from localStorage instead of the server —
// only the interactive leaves (complete button, notes, reflection) have
// anonymous counterparts, since those are the ones that write somewhere.
export function AnonLessonPage({ course, currentModuleId }: AnonLessonPageProps) {
  const [completedIds, setCompletedIds] = useState<Set<string>>(new Set());
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [reflections, setReflections] = useState<Record<string, string>>({});

  // localStorage only exists client-side — hydrate once after mount rather
  // than during render, so server and first client render match.
  useEffect(() => {
    const stored = getAnonProgress(course.id);
    setCompletedIds(new Set(stored.completedModuleIds));
    setNotes(stored.notes);
    setReflections(stored.reflections);
  }, [course.id]);

  const allModules = course.sections.flatMap((s) => s.modules);
  const currentIndex = allModules.findIndex((m) => m.id === currentModuleId);
  const currentModule = allModules[currentIndex];
  if (!currentModule) return null;

  const prevModule = currentIndex > 0 ? allModules[currentIndex - 1] : null;
  const nextModule = currentIndex < allModules.length - 1 ? allModules[currentIndex + 1] : null;

  const progress: ModuleProgress[] = [...completedIds].map((moduleId) => ({
    module_id: moduleId,
    status: "completed",
    last_position_seconds: 0,
    completed_at: null,
    updated_at: "",
  }));
  const { completed: completedCount, total: totalCount } = computeCompletion(allModules.map((m) => m.id), progress);

  function toggleComplete() {
    const willComplete = !completedIds.has(currentModule.id);
    setAnonModuleCompleted(course.id, currentModule.id, willComplete);
    setCompletedIds((prev) => {
      const next = new Set(prev);
      if (willComplete) next.add(currentModule.id);
      else next.delete(currentModule.id);
      return next;
    });
  }

  const isReadable = READABLE_TYPES.has(currentModule.type);
  const notesResult = isReadable && currentModule.content_body ? renderModuleMarkdown(currentModule.content_body) : null;
  const nextPath = ROUTES.courseLearnModule(course.slug, currentModule.id);

  return (
    <div className="flex flex-col items-start gap-6 lg:flex-row">
      <CourseSidebarRail course={course} currentModuleId={currentModuleId} isEnrolled={false} progress={progress} />

      <main className="min-w-0 flex-1">
        <CourseSidebarDrawer
          course={course}
          currentModuleId={currentModuleId}
          currentModuleTitle={currentModule.title}
          isEnrolled={false}
          progress={progress}
        />

        <div className="mx-auto max-w-7xl flex items-start py-6 lg:py-8">
          <article className="min-w-0 flex-1 mx-auto max-w-3xl">
            <AnonCourseBanner nextPath={nextPath} />

            <div className="mb-2 flex items-start justify-between gap-3">
              <h2 className="min-w-0 flex-1 text-2xl font-bold tracking-tight">{currentModule.title}</h2>
            </div>
            <div className="mb-6 flex flex-wrap items-center gap-2">
              <Badge className="gap-1.5 rounded-full border-primary/20 bg-accent px-2.5 py-1 font-mono text-sm capitalize text-primary" variant="outline">
                {MODULE_TYPE_LABEL[currentModule.type] ?? currentModule.type}
              </Badge>
              {currentModule.estimated_minutes && (
                <Badge className="gap-1.5 rounded-full px-2.5 py-1 font-mono text-sm" variant="secondary">
                  <Clock aria-hidden className="h-3.5 w-3.5" />{currentModule.estimated_minutes} min
                </Badge>
              )}
              {completedIds.has(currentModule.id) && (
                <Badge className="badge-success gap-1.5 rounded-full px-2.5 py-1 font-mono text-sm" variant="outline">
                  <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />Completed
                </Badge>
              )}
            </div>

            {isReadable && notesResult ? (
              <AnonModuleNotes
                courseId={course.id}
                initialReflection={reflections[currentModule.id] ?? null}
                isSystemDesign={currentModule.type === "system_design"}
                moduleId={currentModule.id}
                segments={notesResult.segments}
              />
            ) : (
              <div className="empty-state flex-col gap-2 py-16">
                <Lock aria-hidden className="h-10 w-10 text-muted-foreground" />
                <p className="text-sm text-muted-foreground">
                  This lesson type needs an account to open.
                </p>
                <Link className="text-sm font-medium text-primary underline underline-offset-2" href={`${ROUTES.LOGIN}?next=${encodeURIComponent(nextPath)}`}>
                  Sign in to continue
                </Link>
              </div>
            )}

            <ModuleNavFooter
              completeButton={
                isReadable ? (
                  <AnonModuleCompleteButton completed={completedIds.has(currentModule.id)} onToggle={toggleComplete} />
                ) : null
              }
              courseSlug={course.slug}
              nextModule={nextModule}
              prevModule={prevModule}
            />
          </article>

          <ModuleProgressRail>
            <CourseProgressBar completed={completedCount} total={totalCount} />
            {isReadable && (
              <AnonLessonNotes
                courseId={course.id}
                initialContent={notes[currentModule.id] ?? null}
                moduleId={currentModule.id}
              />
            )}
            {notesResult && (
              <div className="min-h-0 flex-1 overflow-y-auto">
                <ModuleToc entries={notesResult.toc} />
              </div>
            )}
          </ModuleProgressRail>
        </div>
      </main>
    </div>
  );
}
