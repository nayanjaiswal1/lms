import type { Metadata } from "next";
import { NotebookPen } from "lucide-react";

import { getJournalCategories, getJournalEntries } from "@/lib/server/journal";
import { JournalPasteCapture } from "@/components/journal/journal-paste-capture";
import { JournalTimeline } from "@/components/journal/journal-timeline";
import { JournalTopicsView } from "@/components/journal/journal-topics-view";
import { JournalToolbar } from "@/components/journal/journal-toolbar";
import { JournalViewTabs } from "@/components/journal/journal-view-tabs";
import { LoadMoreButton } from "@/components/shared/load-more-button";

export const metadata: Metadata = { title: "Learning Journal" };

// Backend defaults/caps this against journal.DefaultListLimit/MaxListLimit
// (internal/journal/models.go) — kept in sync manually, there's no shared
// constants source between the two languages for this.
const DEFAULT_LIMIT = 365;
const LOAD_MORE_STEP = 365;
const MAX_LIMIT = 1000;

interface JournalPageProps {
  searchParams: Promise<{ category?: string; subcategory?: string; q?: string; limit?: string; view?: string }>;
}

export default async function JournalPage({ searchParams }: JournalPageProps) {
  const { category, subcategory, q, limit: limitParam, view } = await searchParams;
  const isTopics = view === "topics";
  const limit = Number(limitParam) || DEFAULT_LIMIT;
  const [entries, categories] = await Promise.all([
    // Topics groups everything into its own tree with its own search, so it
    // ignores the timeline's category/subcategory/q filters and fetches the
    // full set (same "graph view wants every node" reasoning as
    // Handler.GetGraph on the backend) rather than the paginated feed.
    getJournalEntries(isTopics ? { limit: MAX_LIMIT } : { category, subcategory, search: q, limit }),
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

      <div className="mb-4">
        <JournalViewTabs />
      </div>

      {isTopics ? (
        <JournalTopicsView entries={entries} />
      ) : (
        <>
          <JournalToolbar categories={categories} />
          <JournalPasteCapture categories={categories} />

          {entries.length === 0 ? (
            <div className="empty-state">
              <NotebookPen aria-hidden className="empty-state-icon" />
              <p className="font-medium text-muted-foreground">Nothing logged yet.</p>
              <p className="text-sm text-muted-foreground">Add what you learned today to start your journal.</p>
            </div>
          ) : (
            <>
              <JournalTimeline entries={entries} />
              <LoadMoreButton
                defaultLimit={DEFAULT_LIMIT}
                hasMore={entries.length >= limit}
                max={MAX_LIMIT}
                step={LOAD_MORE_STEP}
              />
            </>
          )}
        </>
      )}
    </main>
  );
}
