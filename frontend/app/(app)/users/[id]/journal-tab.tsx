import { NotebookPen } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { JournalEntry } from "@/app/(app)/users/[id]/types";

function EntryCard({ entry }: { entry: JournalEntry }) {
  return (
    <div className="card-base p-4">
      <div className="flex items-center gap-2 flex-wrap">
        <Badge variant="outline">{entry.category}</Badge>
        {entry.subcategory && <Badge variant="secondary">{entry.subcategory}</Badge>}
        <span className="ml-auto text-xs text-muted-foreground shrink-0">
          {new Date(entry.entry_date).toLocaleDateString()}
        </span>
      </div>
      <p className="text-sm font-medium text-foreground mt-2">{entry.title}</p>
      <p className="text-sm text-muted-foreground mt-1 line-clamp-3">{entry.content}</p>
    </div>
  );
}

export function JournalTab({ entries }: { entries: JournalEntry[] }) {
  if (entries.length === 0) {
    return (
      <div className="empty-state">
        <NotebookPen aria-hidden className="empty-state-icon" />
        <p>No journal entries yet.</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {entries.map((e) => (
        <EntryCard entry={e} key={e.id} />
      ))}
    </div>
  );
}
