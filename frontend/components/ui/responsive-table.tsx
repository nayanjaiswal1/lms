"use client";

import type * as React from "react";
import { cn } from "@/lib/utils";

interface ResponsiveTableProps {
  className?: string;
  children: React.ReactNode;
}

/** Copies each column's header text into its body cells' `data-label` (read by `.table-cards` CSS). */
function labelCells(root: HTMLElement) {
  for (const table of root.querySelectorAll("table")) {
    const headRows = table.tHead?.rows;
    if (!headRows?.length) continue;
    const headers = Array.from(headRows[headRows.length - 1].cells, (c) => c.textContent?.trim() ?? "");
    for (const body of table.tBodies) {
      for (const row of body.rows) {
        // colSpan empty-states / expanded detail rows don't line up with headers — leave them full-width.
        if (row.cells.length !== headers.length) continue;
        Array.from(row.cells).forEach((cell, i) => {
          if (cell.getAttribute("data-label") !== headers[i]) cell.setAttribute("data-label", headers[i]);
        });
      }
    }
  }
}

// Ref callback with cleanup (React 19): label once, then relabel when client tables
// swap rows (filters, pagination). Setting data-label is an attribute mutation, and
// only childList is observed, so this can't loop.
// Module-level so its identity is stable and React doesn't re-attach every render.
const attach = (root: HTMLDivElement | null) => {
  if (!root) return;
  labelCells(root);
  const observer = new MutationObserver(() => labelCells(root));
  observer.observe(root, { childList: true, subtree: true });
  return () => observer.disconnect();
};

/**
 * Wrapper for list-style `<table>`s: a normal scrolling table on sm+, and below sm
 * every row becomes a stacked card with each cell labelled by its column header
 * (see `.table-cards` in globals.css) — no horizontal scroll. Callers write a plain table.
 *
 * Not for matrix/grid tables (habit grid, heatmaps, dynamic SQL results) — rows there
 * aren't records, so keep plain `.table-responsive` scrolling.
 */
export function ResponsiveTable({ className, children }: ResponsiveTableProps) {
  return (
    <div className={cn("table-responsive table-cards", className)} ref={attach}>
      {children}
    </div>
  );
}
