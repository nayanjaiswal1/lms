import { QuadrantCard } from "@/components/gitlab-planning/quadrant-card";
import type { AeQuadrant } from "@/lib/gitlab-planning/types";

interface EisenhowerMatrixProps {
  quadrants: AeQuadrant[];
  selectedTaskId: string;
}

const AXIS_LABEL = "absolute text-xs font-bold uppercase tracking-wide text-(--ae-text) whitespace-nowrap";

export function EisenhowerMatrix({ quadrants, selectedTaskId }: EisenhowerMatrixProps) {
  return (
    <section aria-label="Eisenhower matrix" className="order-1 space-y-3 sm:space-y-0 xl:order-none">
      {/* Mobile section heading */}
      <div className="flex items-center justify-between px-0.5 sm:hidden">
        <div>
          <h2 className="text-xs font-bold uppercase tracking-wider text-(--ae-body)">Eisenhower Matrix</h2>
          <p className="text-[11px] text-(--ae-faint)">Tap any quadrant or task to view details</p>
        </div>
        <span className="rounded-full border border-(--ae-brand-200) bg-(--ae-brand-soft) px-2 py-0.5 text-[10px] font-semibold text-(--ae-brand)">
          {quadrants.length} Quadrants
        </span>
      </div>

      <div className="relative sm:pb-6 sm:pl-8 sm:pr-6 sm:pt-5">
        {/* Axes — sm+ only; the touch layout drops them for room */}
        <div className="hidden sm:block" aria-hidden>
          <div className={`${AXIS_LABEL} left-1/2 top-0 -translate-x-1/2`}>Important</div>
          <div className={`${AXIS_LABEL} left-0 top-1/2 -translate-y-1/2 -rotate-90`}>Can Wait</div>
          <div className={`${AXIS_LABEL} right-0 top-1/2 -translate-y-1/2 rotate-90`}>Urgent</div>
          <div className={`${AXIS_LABEL} bottom-0 left-1/2 -translate-x-1/2`}>Unimportant</div>
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
            <div className="relative flex h-px w-full items-center justify-between bg-(--ae-line-strong)">
              <span className="size-0 border-y-4 border-r-6 border-y-transparent border-r-(--ae-line-strong)" />
              <span className="size-0 border-y-4 border-l-6 border-y-transparent border-l-(--ae-line-strong)" />
            </div>
            <div className="absolute flex h-full w-px flex-col items-center justify-between bg-(--ae-line-strong)">
              <span className="size-0 border-x-4 border-b-6 border-x-transparent border-b-(--ae-line-strong)" />
              <span className="size-0 border-x-4 border-t-6 border-x-transparent border-t-(--ae-line-strong)" />
            </div>
          </div>
        </div>

        <div className="relative grid grid-cols-2 gap-2.5 sm:gap-4">
          {quadrants.map((q) => (
            <QuadrantCard key={q.key} quadrant={q} selectedTaskId={selectedTaskId} />
          ))}
        </div>
      </div>
    </section>
  );
}
