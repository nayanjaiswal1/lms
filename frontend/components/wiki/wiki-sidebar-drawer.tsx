"use client";

import { useState } from "react";
import { ListTree, X } from "lucide-react";

import { WikiSidebarTree } from "@/components/wiki/wiki-sidebar-tree";
import { cn } from "@/lib/utils";
import type { WikiPageTreeNode, WikiTemplate } from "@/lib/server/wiki";

interface WikiSidebarDrawerProps {
  spaceSlug: string;
  spaceId: string;
  tree: WikiPageTreeNode[];
  templates: WikiTemplate[];
  currentPath: string[];
  canManage: boolean;
  currentTitle: string;
}

// Mobile equivalent of WikiSidebarTree — same right-anchored drawer shell as
// components/courses/course-sidebar-drawer.tsx. WikiSidebarTree itself stays
// visible unconditionally on lg+ via the wrapping div in each wiki page.
export function WikiSidebarDrawer({ currentTitle, ...treeProps }: WikiSidebarDrawerProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <div className="app-subheader -mx-4 flex items-center gap-3 border-b border-border bg-background/95 px-4 py-3 backdrop-blur-sm sm:-mx-6 sm:px-6 lg:hidden">
        <span className="min-w-0 flex-1 truncate text-sm font-medium">{currentTitle}</span>
        <button
          aria-label="Open wiki pages"
          className="touch-target flex shrink-0 items-center gap-1.5 rounded-md border border-border px-3 text-xs font-medium transition-colors duration-fast hover:bg-muted"
          type="button"
          onClick={() => setOpen(true)}
        >
          <ListTree aria-hidden className="h-4 w-4" />
          Pages
        </button>
      </div>

      {open && (
        <button
          aria-label="Close wiki pages"
          className="sidebar-drawer-backdrop"
          type="button"
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        aria-hidden={!open}
        aria-label="Wiki pages"
        className={cn(
          "fixed inset-y-0 right-0 z-modal flex w-72 sidebar-drawer-right flex-col overflow-y-auto border-l border-sidebar-border bg-sidebar p-3 transition-transform duration-normal ease-smooth lg:hidden",
          "safe-top safe-bottom safe-right",
          open ? "translate-x-0" : "translate-x-full",
        )}
        inert={!open}
      >
        <div className="mb-2 flex items-center justify-end">
          <button
            aria-label="Close wiki pages"
            className="touch-target flex items-center justify-center rounded-md transition-colors duration-fast hover:bg-accent/60"
            type="button"
            onClick={() => setOpen(false)}
          >
            <X aria-hidden className="h-5 w-5" />
          </button>
        </div>
        <WikiSidebarTree {...treeProps} onNavigate={() => setOpen(false)} />
      </aside>
    </>
  );
}
