import { getHighlightAnalytics } from "@/lib/server/highlights";
import { HighlightsTabs } from "@/components/platform/highlights-tabs";

export const metadata = { title: "Highlights by Source Type — Platform Console" };

interface SourceGroup {
  source_type: string;
  entry_count: number;
  total_served: number;
  top_text: string;
}

// entries arrive pre-sorted by serve_count DESC (backend `ORDER BY serve_count DESC`),
// so the first entry seen per group during this scan is that group's most-served one.
function groupBySource(entries: Awaited<ReturnType<typeof getHighlightAnalytics>>): SourceGroup[] {
  const groups = new Map<string, SourceGroup>();
  for (const entry of entries) {
    const existing = groups.get(entry.source_type);
    if (existing) {
      existing.entry_count += 1;
      existing.total_served += entry.serve_count;
    } else {
      groups.set(entry.source_type, {
        source_type: entry.source_type,
        entry_count: 1,
        total_served: entry.serve_count,
        top_text: entry.selected_text,
      });
    }
  }
  return Array.from(groups.values()).sort((a, b) => b.total_served - a.total_served);
}

export default async function PlatformHighlightsBySourcePage() {
  const entries = await getHighlightAnalytics(200);
  const rows = groupBySource(entries);

  return (
    <div className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Highlights by Source Type</h1>
          <p className="text-muted-foreground mt-1">
            Where explanation traffic concentrates: wiki pages, lessons, or problems.
          </p>
        </div>
      </div>

      <HighlightsTabs active="by-source" />

      {rows.length === 0 ? (
        <div className="empty-state py-16">
          <p className="text-muted-foreground">No highlight explanations served yet.</p>
        </div>
      ) : (
        <div className="table-responsive mt-8">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-muted-foreground">
                <th className="pb-2 pr-6 font-medium">Source type</th>
                <th className="pb-2 pr-4 font-medium">Cached entries</th>
                <th className="pb-2 pr-4 font-medium">Total served</th>
                <th className="pb-2 font-medium">Most-served example</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr className="border-b border-border last:border-0 hover:bg-muted/30 transition-colors" key={row.source_type}>
                  <td className="py-3 pr-6 font-medium">{row.source_type}</td>
                  <td className="py-3 pr-4 text-muted-foreground">{row.entry_count}</td>
                  <td className="py-3 pr-4 text-foreground font-medium">{row.total_served}</td>
                  <td className="py-3 max-w-md">
                    <span className="line-clamp-2 text-muted-foreground">{row.top_text}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
