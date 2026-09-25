import { MoreVertical, Plus } from "lucide-react";
import type { AeQuadrant } from "@/lib/server/gitlab-planning";
import { cn } from "@/lib/utils";

interface QuadrantCardProps {
  quadrant: AeQuadrant;
  selectedTaskId: string;
}

export function QuadrantCard({ quadrant, selectedTaskId }: QuadrantCardProps) {
  const top = quadrant.key === "plan" || quadrant.key === "do_now";

  return (
    <div
      className={cn(
        "flex flex-col justify-between card-base bg-linear-to-b from-(--t-50)/40 to-(--t-50)/40 p-3 shadow-card sm:p-4 sm:shadow-card",
        top ? "sm:min-h-52" : "sm:min-h-44",
        // Mobile puts "Do it Now" first, like the Stitch touch layout.
        quadrant.key === "do_now" && "max-sm:order-first",
      )}
      data-tone={quadrant.tone}
    >
      <div>
        <div className="mb-1 flex-between sm:mb-0.5">
          <h3 className="truncate text-xs font-bold text-(--t-900) sm:text-sm">{quadrant.title}</h3>
          <span className="flex size-5 shrink-0 items-center justify-center rounded-full bg-(--t-100) text-xs font-bold text-(--t-700) sm:text-xs">
            {quadrant.tasks.length}
          </span>
        </div>
        <p className="mb-2.5 text-xs font-medium text-(--t-sub)/80 sm:mb-3 sm:text-xs">{quadrant.subtitle}</p>
        <ul className="space-y-1.5 sm:space-y-2">
          {quadrant.tasks.map((task) => {
            const selected = task.id === selectedTaskId;
            return (
              <li
                className={cn(
                  "flex cursor-pointer items-center justify-between rounded-xl bg-card p-2 transition-colors sm:px-3 sm:py-2",
                  selected
                    ? "border-2 border-(--ae-brand-500) shadow-card"
                    : "border border-border/80 shadow-card hover:border-border",
                )}
                key={task.id}
              >
                <div className="flex min-w-0 items-center gap-1.5 sm:gap-2.5">
                  <span className="size-2 shrink-0 rounded-full bg-(--t-dot) sm:size-2.5" data-tone={task.dot} />
                  <span className={cn("truncate text-xs sm:text-xs", selected ? "font-bold text-foreground" : "font-semibold text-foreground")}>
                    {task.title}
                  </span>
                </div>
                <button aria-label={`More actions for ${task.title}`} className="hidden text-muted-foreground hover:text-muted-foreground sm:block" type="button">
                  <MoreVertical aria-hidden className="size-4" />
                </button>
              </li>
            );
          })}
        </ul>
      </div>
      <button
        className="mt-2.5 flex w-full items-center justify-center gap-1 rounded-xl border border-dashed border-border py-1.5 text-xs font-semibold text-(--t-700) transition-colors hover:bg-(--t-100)/50 sm:mt-3 sm:text-xs"
        type="button"
      >
        <Plus aria-hidden className="size-3.5" />
        Add task
      </button>
    </div>
  );
}
