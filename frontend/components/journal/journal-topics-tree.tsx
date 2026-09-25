"use client";

import { useMemo, useState } from "react";
import { useQueryState } from "nuqs";
import { ChevronDown, FileText, Search, X } from "lucide-react";

import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { journalTagSwatchClass } from "@/lib/journal/tag-color";
import type { JournalEntry } from "@/lib/server/journal";

interface JournalTopicsTreeProps {
  entries: JournalEntry[];
  /** Closes the mobile drawer after an entry is selected. */
  onNavigate?: () => void;
}

interface CategoryGroup {
  category: string;
  entries: JournalEntry[];
}

function groupByCategory(entries: JournalEntry[]): CategoryGroup[] {
  const order: string[] = [];
  const byCategory = new Map<string, JournalEntry[]>();
  for (const entry of entries) {
    const existing = byCategory.get(entry.category);
    if (existing) {
      existing.push(entry);
      continue;
    }
    order.push(entry.category);
    byCategory.set(entry.category, [entry]);
  }
  return order.map((category) => ({ category, entries: byCategory.get(category) ?? [] }));
}

// The Journal's course-page-style tree: category = section, entry = module.
// Mirrors components/courses/course-sidebar.tsx's shape (collapsible
// sections, search, row-per-item) — no completion/progress here, since a
// journal entry has no "done" state to track.
export function JournalTopicsTree({ entries, onNavigate }: JournalTopicsTreeProps) {
  const [selected, setSelected] = useQueryState("entry", { defaultValue: "", shallow: false });
  const [query, setQuery] = useState("");
  const trimmed = query.trim().toLowerCase();
  const isSearching = trimmed.length > 0;

  const groups = useMemo(() => groupByCategory(entries), [entries]);

  return (
    <nav aria-label="Journal topics" className="flex h-full flex-col">
      <div className="flex flex-col gap-3 px-4 pt-4">
        <div className="relative">
          <Search aria-hidden className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            aria-label="Search topics"
            className="pl-9 pr-9 focus-visible:ring-offset-0"
            placeholder="Search topics…"
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          {isSearching && (
            <button
              aria-label="Clear search"
              className="absolute right-1.5 top-1/2 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded text-muted-foreground transition-colors duration-fast hover:text-foreground"
              type="button"
              onClick={() => setQuery("")}
            >
              <X aria-hidden className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      </div>

      <div className="mt-3 flex flex-col gap-1 overflow-y-auto pb-4">
        {groups.map((group) => {
          const groupEntries = isSearching
            ? group.entries.filter((e) => e.title.toLowerCase().includes(trimmed))
            : group.entries;
          if (isSearching && groupEntries.length === 0) return null;

          const containsSelected = group.entries.some((e) => e.id === selected);

          return (
            <details className="group" key={group.category} open={isSearching || containsSelected}>
              <summary className="flex cursor-pointer list-none items-center gap-2 px-4 py-2 text-sm font-semibold text-foreground transition-colors duration-fast hover:bg-muted">
                <ChevronDown aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-fast group-open:rotate-180" />
                <span className="min-w-0 flex-1 truncate">{group.category}</span>
                <span className="shrink-0 text-xs font-normal text-muted-foreground">{group.entries.length}</span>
              </summary>

              <ul className="flex list-none flex-col">
                {groupEntries.map((entry) => {
                  const isCurrent = entry.id === selected;
                  return (
                    <li key={entry.id}>
                      <button
                        aria-current={isCurrent ? "true" : undefined}
                        className={cn(
                          "flex w-full items-center gap-3 border-l-2 border-transparent py-2.5 pl-6 pr-4 text-left text-sm text-foreground transition-colors duration-fast hover:bg-muted",
                          isCurrent && "border-primary bg-primary/8 font-medium text-primary",
                        )}
                        type="button"
                        onClick={() => {
                          void setSelected(entry.id);
                          onNavigate?.();
                        }}
                      >
                        <span
                          aria-hidden
                          className={cn("size-2 shrink-0 rounded-full", journalTagSwatchClass(entry.category, entry.subcategory))}
                        />
                        {entry.source === "task" ? (
                          <FileText aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
                        ) : null}
                        <span className="line-clamp-2 min-w-0 flex-1 leading-snug">{entry.title}</span>
                        <span className="ml-auto shrink-0 text-xs text-muted-foreground">{entry.subcategory}</span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </details>
          );
        })}

        {groups.length === 0 && (
          <p className="px-4 py-6 text-center text-sm text-muted-foreground">Nothing logged yet.</p>
        )}
      </div>
    </nav>
  );
}
