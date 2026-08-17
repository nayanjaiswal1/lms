import { AlertTriangle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { MistakeCategorySummary, MistakeEntry } from "@/app/(app)/users/[id]/types";

const trendClass: Record<MistakeCategorySummary["trend"], string> = {
  worsening: "bg-destructive/10 text-destructive border-destructive/30",
  stable: "bg-muted text-muted-foreground border-border",
  improving: "bg-success/10 text-success border-success/30",
};

function SummaryRow({ summary }: { summary: MistakeCategorySummary }) {
  return (
    <div className="flex items-center gap-3 py-2.5 border-b border-border last:border-0">
      <span className="text-sm font-medium text-foreground flex-1 min-w-0 truncate">{summary.category}</span>
      <Badge variant="outline">{summary.total}</Badge>
      <Badge className={trendClass[summary.trend]} variant="outline">
        {summary.trend}
      </Badge>
    </div>
  );
}

function EntryRow({ entry }: { entry: MistakeEntry }) {
  return (
    <div className="py-3 border-b border-border last:border-0">
      <div className="flex items-center gap-2">
        <Badge variant="outline">{entry.category}</Badge>
        <Badge variant={entry.resolved_at ? "secondary" : "destructive"}>
          {entry.resolved_at ? "resolved" : entry.status}
        </Badge>
        <span className="ml-auto text-xs text-muted-foreground shrink-0">
          {new Date(entry.created_at).toLocaleDateString()}
        </span>
      </div>
      <p className="text-sm text-foreground mt-1.5">{entry.original_text}</p>
      {entry.corrected_text && (
        <p className="text-sm text-success mt-1">→ {entry.corrected_text}</p>
      )}
    </div>
  );
}

export function MistakesTab({ entries, summary }: { entries: MistakeEntry[]; summary: MistakeCategorySummary[] }) {
  if (entries.length === 0) {
    return (
      <div className="empty-state">
        <AlertTriangle aria-hidden className="empty-state-icon" />
        <p>No mistakes logged.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {summary.length > 0 && (
        <div className="card-base p-6">
          <h3 className="subsection-title text-foreground mb-2">By category</h3>
          {summary.map((s) => (
            <SummaryRow key={s.category} summary={s} />
          ))}
        </div>
      )}

      <div className="card-base p-6">
        <h3 className="subsection-title text-foreground mb-2">Timeline</h3>
        {entries.map((e) => (
          <EntryRow entry={e} key={e.id} />
        ))}
      </div>
    </div>
  );
}
