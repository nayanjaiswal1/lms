"use client";

import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, ListTree, X } from "lucide-react";
import { CourseSidebar } from "@/components/courses/course-sidebar";
import { cn } from "@/lib/utils";
import type { CourseTree, ModuleProgress } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface CourseSidebarDrawerProps {
  course: CourseTree;
  currentModuleId: string;
  currentModuleTitle: string;
  progress: ModuleProgress[];
  isEnrolled: boolean;
}

// The full course tree lives in a right-anchored drawer on mobile — kept
// distinct from the app's own left-anchored nav drawer (mobile-nav.tsx) so
// the two never look interchangeable.
export function CourseSidebarDrawer({
  course,
  currentModuleId,
  currentModuleTitle,
  progress,
  isEnrolled,
}: CourseSidebarDrawerProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <div className="app-subheader -mx-4 flex items-center gap-3 border-b border-border bg-background/95 px-4 py-3 backdrop-blur-sm sm:-mx-6 sm:px-6 lg:hidden">
        <Link
          aria-label="Back to course overview"
          className="touch-target -ml-2 flex shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors duration-fast hover:bg-muted hover:text-foreground"
          href={ROUTES.course(course.slug)}
        >
          <ArrowLeft aria-hidden className="h-5 w-5" />
        </Link>
        <span className="min-w-0 flex-1 truncate text-sm font-medium">{currentModuleTitle}</span>
        <button
          aria-label="Open course contents"
          className="touch-target flex shrink-0 items-center gap-1.5 rounded-md border border-border px-3 text-xs font-medium transition-colors duration-fast hover:bg-muted"
          onClick={() => setOpen(true)}
        >
          <ListTree aria-hidden className="h-4 w-4" />
          Contents
        </button>
      </div>

      {open && (
        <button
          aria-label="Close course contents"
          className="sidebar-drawer-backdrop"
          type="button"
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        aria-hidden={!open}
        aria-label="Course contents"
        className={cn(
          "fixed inset-y-0 right-0 z-modal flex w-72 max-w-[85vw] flex-col border-l border-sidebar-border bg-sidebar transition-transform duration-normal ease-smooth lg:hidden",
          "safe-top safe-bottom safe-right",
          open ? "translate-x-0" : "translate-x-full",
        )}
        inert={!open}
      >
        <div className="flex items-center justify-between border-b border-sidebar-border px-4 py-4">
          <span className="text-sm font-semibold">Course contents</span>
          <button
            aria-label="Close course contents"
            className="touch-target flex items-center justify-center rounded-md transition-colors duration-fast hover:bg-accent/60"
            onClick={() => setOpen(false)}
          >
            <X aria-hidden className="h-5 w-5" />
          </button>
        </div>
        <CourseSidebar
          course={course}
          currentModuleId={currentModuleId}
          isEnrolled={isEnrolled}
          progress={progress}
          onNavigate={() => setOpen(false)}
        />
      </aside>
    </>
  );
}
