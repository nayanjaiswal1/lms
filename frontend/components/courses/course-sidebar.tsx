import Link from "next/link";
import { CheckCircle2, Circle, Lock, PlayCircle, FileText, ClipboardCheck } from "lucide-react";
import { cn } from "@/lib/utils";
import type { CourseTree, ModuleProgress } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface CourseSidebarProps {
  course: CourseTree;
  currentModuleId?: string;
  progress: ModuleProgress[];
}

const TYPE_ICON: Record<string, React.ComponentType<{ className?: string; "aria-hidden"?: boolean }>> = {
  video:      PlayCircle,
  pdf:        FileText,
  notes:      FileText,
  assessment: ClipboardCheck,
};

function progressStatus(moduleId: string, progress: ModuleProgress[]): "completed" | "in_progress" | "not_started" {
  const p = progress.find((p) => p.module_id === moduleId);
  return p?.status ?? "not_started";
}

export function CourseSidebar({ course, currentModuleId, progress }: CourseSidebarProps) {
  return (
    <nav aria-label="Course modules" className="flex flex-col gap-4">
      <header className="px-4 pt-4">
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Contents</p>
      </header>

      {course.sections.map((section) => (
        <section key={section.id}>
          <h3 className="px-4 py-1 text-sm font-semibold">{section.title}</h3>
          <ul className="flex flex-col">
            {section.modules.map((mod) => {
              const status = progressStatus(mod.id, progress);
              const Icon = TYPE_ICON[mod.type] ?? FileText;
              const isCurrent = mod.id === currentModuleId;

              return (
                <li key={mod.id}>
                  <Link
                    href={ROUTES.courseLearnModule(course.slug, mod.id)}
                    className={cn(
                      "flex items-center gap-3 px-4 py-2.5 text-sm transition-colors duration-fast hover:bg-muted",
                      isCurrent && "bg-muted font-medium text-primary",
                    )}
                    aria-current={isCurrent ? "page" : undefined}
                  >
                    {status === "completed" ? (
                      <CheckCircle2 aria-label="Completed" className="h-4 w-4 shrink-0 text-primary" />
                    ) : status === "in_progress" ? (
                      <Circle aria-label="In progress" className="h-4 w-4 shrink-0 text-primary opacity-60" />
                    ) : (
                      <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                    )}
                    <span className="line-clamp-2 leading-snug">{mod.title}</span>
                    {mod.estimated_minutes && (
                      <span className="ml-auto shrink-0 text-xs text-muted-foreground">{mod.estimated_minutes}m</span>
                    )}
                    {!mod.is_free_preview && status === "not_started" && (
                      <Lock aria-label="Requires enrollment" className="ml-auto h-3 w-3 shrink-0 text-muted-foreground" />
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </nav>
  );
}
