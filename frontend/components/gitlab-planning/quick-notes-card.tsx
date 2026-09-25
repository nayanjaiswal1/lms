import { Maximize2, NotebookPen } from "lucide-react";

export function QuickNotesCard() {
  return (
    <section aria-label="Quick notes" className="flex scroll-mt-20 flex-col rounded-2xl border border-(--ae-line)/80 bg-(--ae-card) p-4 shadow-sm" id="quick-notes">
      <div className="mb-2 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <NotebookPen aria-hidden className="size-4 text-(--ae-muted)" />
          <h3 className="text-xs font-bold text-(--ae-ink)">Quick Notes</h3>
        </div>
        <button aria-label="Expand quick notes" className="text-(--ae-faint) hover:text-(--ae-dim)" type="button">
          <Maximize2 aria-hidden className="size-4" />
        </button>
      </div>
      <textarea
        aria-label="Quick notes"
        className="w-full resize-none border-none bg-transparent p-0 text-xs text-(--ae-body) placeholder:text-(--ae-faint) focus:outline-none focus:ring-0"
        placeholder="Write notes, ideas or anything..."
        rows={3}
      />
    </section>
  );
}
