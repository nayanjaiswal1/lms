"use client";

import { useState } from "react";
import Link from "next/link";
import { BookOpen, ChevronDown, CheckCircle2, Circle, Lock, FileText, Search, X } from "lucide-react";
import { cn } from "@/lib/utils";
import type { CourseTree, ModuleProgress } from "@/lib/server/courses";
import { MODULE_TYPE_ICON } from "@/lib/courses/module-types";
import { moduleStatus, computeCompletion } from "@/lib/courses/progress";
import { CourseProgressBar } from "@/components/courses/course-progress-bar";
import { Tooltip, TooltipTrigger, TooltipContent } from "@/components/ui/tooltip";
import { Input } from "@/components/ui/input";
import ROUTES from "@/lib/routes";

interface CourseSidebarProps {
  course: CourseTree;
  currentModuleId?: string;
  progress: ModuleProgress[];
  isEnrolled: boolean;
  /** Closes the mobile drawer after a module link is clicked. */
  onNavigate?: () => void;
}

export function CourseSidebar({ course, currentModuleId, progress, isEnrolled, onNavigate }: CourseSidebarProps) {
  const [query, setQuery] = useState("");
  const trimmed = query.trim().toLowerCase();
  const isSearching = trimmed.length > 0;

  const allModules = course.sections.flatMap((s) => s.modules);
  const { completed: completedCount, total: totalCount } = computeCompletion(allModules.map((m) => m.id), progress);
  const hasMatches = !isSearching || allModules.some((m) => m.title.toLowerCase().includes(trimmed));

  return (
    <nav aria-label="Course modules" className="flex h-full flex-col">
      <div className="flex flex-col gap-3 px-4 pt-4">
        <div className="flex flex-col gap-2 border-b border-sidebar-border pb-3">
          <Tooltip>
            <TooltipTrigger asChild>
              <Link
                className="-mx-1.5 flex items-start gap-1.5 rounded-md px-1.5 py-1 transition-colors duration-fast hover:bg-muted"
                href={ROUTES.course(course.slug)}
              >
                <BookOpen aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
                <h2 className="line-clamp-2 min-w-0 flex-1 text-sm font-semibold leading-snug text-foreground">{course.title}</h2>
              </Link>
            </TooltipTrigger>
            <TooltipContent side="bottom">Course overview</TooltipContent>
          </Tooltip>
          {/* At xl+ this progress bar moves into the ModuleProgressRail instead. */}
          <CourseProgressBar className="xl:hidden" completed={completedCount} total={totalCount} />
        </div>

        <div className="relative">
          <Search aria-hidden className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            aria-label="Search modules"
            className="pl-9 pr-9 focus-visible:ring-0 focus-visible:ring-offset-0"
            placeholder="Search modules…"
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          {isSearching && (
            <button
              aria-label="Clear search"
              className="absolute right-1.5 top-1/2 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded text-muted-foreground transition-colors duration-fast hover:text-foreground"
              type="button"
              onClick={() => setQuery("")}
            >
              <X aria-hidden className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      </div>

      <div className="mt-2 flex flex-col gap-1 overflow-y-auto pb-4">
        {course.sections.map((section) => {
          const sectionModules = isSearching
            ? section.modules.filter((m) => m.title.toLowerCase().includes(trimmed))
            : section.modules;

          if (isSearching && sectionModules.length === 0) return null;

          const { completed: sectionCompleted } = computeCompletion(section.modules.map((m) => m.id), progress);
          const containsCurrent = section.modules.some((m) => m.id === currentModuleId);

          return (
            <details className="group" key={section.id} open={isSearching || containsCurrent}>
              <summary className="flex cursor-pointer list-none items-center gap-2 px-4 py-2 text-sm font-semibold text-foreground transition-colors duration-fast hover:bg-muted">
                <ChevronDown aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-fast group-open:rotate-180" />
                <span className="min-w-0 flex-1 truncate">{section.title}</span>
                <span className="shrink-0 text-xs font-normal text-muted-foreground">{sectionCompleted}/{section.modules.length}</span>
              </summary>

              <ul className="flex list-none flex-col">
                {sectionModules.map((mod) => {
                  const status = moduleStatus(mod.id, progress);
                  const Icon = MODULE_TYPE_ICON[mod.type] ?? FileText;
                  const isCurrent = mod.id === currentModuleId;
                  const isLocked = !isEnrolled && !mod.is_free_preview;

                  return (
                    <li key={mod.id}>
                      <Link
                        aria-current={isCurrent ? "page" : undefined}
                        className={cn(
                          "flex items-center gap-3 border-l-2 border-transparent py-2.5 pl-6 pr-4 text-sm text-foreground transition-colors duration-fast hover:bg-muted",
                          isCurrent && "border-primary bg-primary/8 font-medium text-primary",
                        )}
                        href={ROUTES.courseLearnModule(course.slug, mod.id)}
                        onClick={onNavigate}
                      >
                        {status === "completed" ? (
                          <CheckCircle2 aria-label="Completed" className="h-4 w-4 shrink-0 text-primary" />
                        ) : status === "in_progress" ? (
                          <Circle aria-label="In progress" className="h-4 w-4 shrink-0 text-primary opacity-60" />
                        ) : (
                          <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                        )}
                        <span className="line-clamp-2 min-w-0 flex-1 leading-snug">{mod.title}</span>
                        {isLocked ? (
                          <Lock aria-label="Requires enrollment" className="ml-auto h-3 w-3 shrink-0 text-muted-foreground" />
                        ) : (
                          mod.estimated_minutes && (
                            <span className="ml-auto shrink-0 text-xs text-muted-foreground">{mod.estimated_minutes}m</span>
                          )
                        )}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </details>
          );
        })}

        {!hasMatches && (
          <p className="px-4 py-6 text-center text-sm text-muted-foreground">No modules match &ldquo;{query}&rdquo;.</p>
        )}
      </div>
    </nav>
  );
}
