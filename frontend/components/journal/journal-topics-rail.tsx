import { LayoutGrid } from "lucide-react";

import { JournalTopicsTree } from "@/components/journal/journal-topics-tree";
import type { JournalEntry } from "@/lib/server/journal";

// Desktop sticky rail for the Journal's "Topics" view — same sticky/border
// shell as components/courses/course-sidebar-rail.tsx, minus that one's
// drag-to-resize and "back to dashboard" link (this isn't a separate page,
// just a view mode on /journal itself). Fixed w-72 (288px) instead of that
// one's resizable width — a nice-to-have this view doesn't need yet.
export function JournalTopicsRail({ entries }: { entries: JournalEntry[] }) {
  return (
    <aside className="relative hidden w-72 shrink-0 lg:sticky-rail lg:top-16 lg:flex lg:max-h-[calc(100dvh-4rem)] lg:flex-col lg:overflow-hidden lg:rounded-lg lg:border lg:border-sidebar-border lg:bg-sidebar">
      <div className="flex shrink-0 items-center gap-2 border-b border-sidebar-border px-5 py-4">
        <LayoutGrid aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
        <span className="text-sm font-semibold text-foreground">Topics</span>
      </div>
      <div className="overflow-y-auto">
        <JournalTopicsTree entries={entries} />
      </div>
    </aside>
  );
}
