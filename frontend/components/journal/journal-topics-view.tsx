"use client";

import { useQueryState } from "nuqs";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { NotebookPen } from "lucide-react";

import { JournalTopicsRail } from "@/components/journal/journal-topics-rail";
import { JournalTopicsDrawer } from "@/components/journal/journal-topics-drawer";
import type { JournalEntry } from "@/lib/server/journal";

// The Journal's course-page-style layout: a topic tree (rail on desktop,
// drawer on mobile — see components/courses/course-sidebar-rail.tsx /
// -drawer.tsx) next to a reading pane for whichever entry is selected.
// Selection lives in the URL (?entry=) so it's shareable/refresh-safe, same
// as every other filter/sort/page state in this app.
export function JournalTopicsView({ entries }: { entries: JournalEntry[] }) {
  const [selectedId] = useQueryState("entry", { defaultValue: "", shallow: false });
  const selected = entries.find((e) => e.id === selectedId) ?? entries[0] ?? null;

  return (
    <div className="flex flex-col items-start gap-6 lg:flex-row">
      <JournalTopicsRail entries={entries} />
      <JournalTopicsDrawer currentTitle={selected?.title ?? "Topics"} entries={entries} />

      <main className="min-w-0 flex-1">
        {selected ? (
          <article className="mx-auto max-w-3xl py-2">
            <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
              {selected.category} / {selected.subcategory}
            </span>
            <h2 className="mb-4 mt-1 text-2xl font-bold tracking-tight text-foreground">{selected.title}</h2>
            <div className="prose-content">
              <ReactMarkdown remarkPlugins={[remarkGfm]}>{selected.content}</ReactMarkdown>
            </div>
          </article>
        ) : (
          <div className="empty-state py-16">
            <NotebookPen aria-hidden className="empty-state-icon" />
            <p className="font-medium text-muted-foreground">Nothing logged yet.</p>
            <p className="text-sm text-muted-foreground">Add what you learned today to start building topics.</p>
          </div>
        )}
      </main>
    </div>
  );
}
