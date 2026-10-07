import { Maximize2, NotebookPen } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
export function QuickNotesCard() {
  return (
    <section aria-label="Quick notes" className="flex scroll-mt-20 flex-col card-base shadow-card" id="quick-notes">
      <div className="mb-2 flex-between">
        <div className="flex items-center gap-2">
          <NotebookPen aria-hidden className="size-4 text-muted-foreground" />
          <h3 className="text-xs font-bold text-foreground">Quick Notes</h3>
        </div>
        <Button aria-label="Expand quick notes" className="text-muted-foreground hover:text-muted-foreground" type="button" variant="unstyled">
          <Maximize2 aria-hidden className="size-4" />
        </Button>
      </div>
      <Textarea
        aria-label="Quick notes"
        className="min-h-0 resize-none rounded-none border-none bg-transparent p-0 text-xs text-foreground placeholder:text-muted-foreground focus:outline-none"
        placeholder="Write notes, ideas or anything..."
        rows={3}
      />
    </section>
  );
}
