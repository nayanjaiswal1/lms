import type { Metadata } from "next";
import { NotebookPen } from "lucide-react";

import { getJournalCategories, getJournalEntries } from "@/lib/server/journal";
import { JournalPasteCapture } from "@/components/journal/journal-paste-capture";
import { JournalTimeline } from "@/components/journal/journal-timeline";
import { JournalToolbar } from "@/components/journal/journal-toolbar";

export const metadata: Metadata = { title: "Learning Journal" };

interface JournalPageProps {
  searchParams: Promise<{ category?: string; subcategory?: string; q?: string }>;
}

export default async function JournalPage({ searchParams }: JournalPageProps) {
  const { category, subcategory, q } = await searchParams;
  const [entries, categories] = await Promise.all([
    getJournalEntries({ category, subcategory, search: q }),
    getJournalCategories(),
  ]);

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Learning Journal</h1>
          <p className="text-sm text-muted-foreground">What you learned, day by day.</p>
        </div>
      </div>

      <JournalToolbar categories={categories} />
      <JournalPasteCapture categories={categories} />

      {entries.length === 0 ? (
        <div className="empty-state">
          <NotebookPen aria-hidden className="empty-state-icon" />
          <p className="font-medium text-muted-foreground">Nothing logged yet.</p>
          <p className="text-sm text-muted-foreground">Add what you learned today to start your journal.</p>
        </div>
      ) : (
        <JournalTimeline entries={entries} />
      )}
    </main>
  );
}
