"use client";

import { useState } from "react";
import { ListTree, X } from "lucide-react";

import { JournalTopicsTree } from "@/components/journal/journal-topics-tree";
import { cn } from "@/lib/utils";
import type { JournalEntry } from "@/lib/server/journal";

// Mobile equivalent of JournalTopicsRail — same right-anchored drawer shell
// as components/courses/course-sidebar-drawer.tsx.
export function JournalTopicsDrawer({ entries, currentTitle }: { entries: JournalEntry[]; currentTitle: string }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <div className="app-subheader -mx-4 flex items-center gap-3 border-b border-border bg-background/95 px-4 py-3 backdrop-blur-sm sm:-mx-6 sm:px-6 lg:hidden">
        <span className="min-w-0 flex-1 truncate text-sm font-medium">{currentTitle}</span>
        <button
          aria-label="Open topics"
          className="touch-target flex shrink-0 items-center gap-1.5 rounded-md border border-border px-3 text-xs font-medium transition-colors duration-fast hover:bg-muted"
          type="button"
          onClick={() => setOpen(true)}
        >
          <ListTree aria-hidden className="h-4 w-4" />
          Topics
        </button>
      </div>

      {open && (
        <button
          aria-label="Close topics"
          className="sidebar-drawer-backdrop"
          type="button"
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        aria-hidden={!open}
        aria-label="Journal topics"
        className={cn(
          "fixed inset-y-0 right-0 z-modal flex w-72 sidebar-drawer-right flex-col border-l border-sidebar-border bg-sidebar transition-transform duration-normal ease-smooth lg:hidden",
          "safe-top safe-bottom safe-right",
          open ? "translate-x-0" : "translate-x-full",
        )}
        inert={!open}
      >
        <div className="flex-between border-b border-sidebar-border px-4 py-4">
          <span className="text-sm font-semibold">Topics</span>
          <button
            aria-label="Close topics"
            className="touch-target flex items-center justify-center rounded-md transition-colors duration-fast hover:bg-accent/60"
            type="button"
            onClick={() => setOpen(false)}
          >
            <X aria-hidden className="h-5 w-5" />
          </button>
        </div>
        <JournalTopicsTree entries={entries} onNavigate={() => setOpen(false)} />
      </aside>
    </>
  );
}
