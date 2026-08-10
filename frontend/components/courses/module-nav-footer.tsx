import Link from "next/link";
import { ArrowLeft, ArrowRight } from "lucide-react";
import ROUTES from "@/lib/routes";

interface AdjacentModule {
  id: string;
  title: string;
}

interface ModuleNavFooterProps {
  courseSlug: string;
  prevModule: AdjacentModule | null;
  nextModule: AdjacentModule | null;
  completeButton?: React.ReactNode;
}

export function ModuleNavFooter({ courseSlug, prevModule, nextModule, completeButton }: ModuleNavFooterProps) {
  if (!prevModule && !nextModule && !completeButton) return null;

  return (
    <div className="mt-10 flex flex-col gap-3">
      {completeButton}
      {(prevModule || nextModule) && (
        <nav
          aria-label="Module navigation"
          className="flex divide-x divide-border overflow-hidden rounded-xl border border-border bg-card shadow-card"
        >
          {prevModule ? (
            <Link
              className="flex flex-1 items-center gap-2 px-4 py-3 transition-colors duration-fast hover:bg-muted"
              href={ROUTES.courseLearnModule(courseSlug, prevModule.id)}
            >
              <ArrowLeft aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
              <span className="flex min-w-0 flex-col">
                <span className="text-xs text-muted-foreground">Previous</span>
                <span className="line-clamp-1 text-sm font-medium text-foreground">{prevModule.title}</span>
              </span>
            </Link>
          ) : (
            <div className="flex-1" />
          )}

          {nextModule ? (
            <Link
              className="flex flex-1 items-center justify-end gap-2 px-4 py-3 text-right transition-colors duration-fast hover:bg-muted"
              href={ROUTES.courseLearnModule(courseSlug, nextModule.id)}
            >
              <span className="flex min-w-0 flex-col items-end">
                <span className="text-xs text-muted-foreground">Next</span>
                <span className="line-clamp-1 text-sm font-medium text-foreground">{nextModule.title}</span>
              </span>
              <ArrowRight aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
            </Link>
          ) : (
            <div className="flex-1" />
          )}
        </nav>
      )}
    </div>
  );
}
