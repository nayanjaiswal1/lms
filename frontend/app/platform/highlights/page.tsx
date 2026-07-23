import { getHighlightAnalytics } from "@/lib/server/highlights";
import { HighlightsTabs } from "@/components/platform/highlights-tabs";

export const metadata = { title: "Confusing Content — Platform Console" };

function fmt(iso: string): string {
  return new Date(iso).toLocaleString(undefined, {
    month:  "short",
    day:    "numeric",
    hour:   "2-digit",
    minute: "2-digit",
  });
}

export default async function PlatformHighlightsPage() {
  const entries = await getHighlightAnalytics(200);

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Confusing Content</h1>
          <p className="text-muted-foreground mt-1">
            Text snippets students ask AI to explain most often, across all organisations.
          </p>
        </div>
      </div>

      <HighlightsTabs active="all" />

      {entries.length === 0 ? (
        <div className="empty-state py-16">
          <p className="text-muted-foreground">No highlight explanations served yet.</p>
        </div>
      ) : (
        <div className="table-responsive mt-8">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="pb-2 pr-6 font-medium">Selected text</th>
                <th className="pb-2 pr-4 font-medium">Source</th>
                <th className="pb-2 pr-4 font-medium">Served</th>
                <th className="pb-2 pr-4 font-medium">Model</th>
                <th className="pb-2 font-medium">Last served</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry) => (
                <tr className="border-b border-border last:border-0 hover:bg-muted/30 transition-colors" key={entry.text_hash}>
                  <td className="py-3 pr-6 max-w-md">
                    <span className="line-clamp-2">{entry.selected_text}</span>
                  </td>
                  <td className="py-3 pr-4 text-muted-foreground">{entry.source_type}</td>
                  <td className="py-3 pr-4 text-foreground font-medium">{entry.serve_count}</td>
                  <td className="py-3 pr-4 text-muted-foreground font-mono text-xs">{entry.model_used}</td>
                  <td className="py-3 text-muted-foreground">{fmt(entry.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
