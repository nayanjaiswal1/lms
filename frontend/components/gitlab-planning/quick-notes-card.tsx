import { Maximize2, NotebookPen } from "lucide-react";

export function QuickNotesCard() {
  return (
    <section aria-label="Quick notes" className="flex scroll-mt-20 flex-col card-base shadow-card" id="quick-notes">
      <div className="mb-2 flex-between">
        <div className="flex items-center gap-2">
          <NotebookPen aria-hidden className="size-4 text-muted-foreground" />
          <h3 className="text-xs font-bold text-foreground">Quick Notes</h3>
        </div>
        <button aria-label="Expand quick notes" className="text-muted-foreground hover:text-muted-foreground" type="button">
          <Maximize2 aria-hidden className="size-4" />
        </button>
      </div>
      <textarea
        aria-label="Quick notes"
        className="w-full resize-none border-none bg-transparent p-0 text-xs text-foreground placeholder:text-muted-foreground focus:outline-none"
        placeholder="Write notes, ideas or anything..."
        rows={3}
      />
    </section>
  );
}
