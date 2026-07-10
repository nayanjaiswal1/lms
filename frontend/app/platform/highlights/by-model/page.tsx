import { getHighlightAnalytics } from "@/lib/server/highlights";

export const metadata = { title: "Highlights by Model — Platform Console" };

interface ModelGroup {
  model_used: string;
  entry_count: number;
  total_served: number;
}

function groupByModel(entries: Awaited<ReturnType<typeof getHighlightAnalytics>>): ModelGroup[] {
  const groups = new Map<string, ModelGroup>();
  for (const entry of entries) {
    const existing = groups.get(entry.model_used);
    if (existing) {
      existing.entry_count += 1;
      existing.total_served += entry.serve_count;
    } else {
      groups.set(entry.model_used, {
        model_used:   entry.model_used,
        entry_count:  1,
        total_served: entry.serve_count,
      });
    }
  }
  return Array.from(groups.values()).sort((a, b) => b.total_served - a.total_served);
}

export default async function PlatformHighlightsByModelPage() {
  const entries = await getHighlightAnalytics(200);
  const rows = groupByModel(entries);

  return (
    <div className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Highlights by Model</h1>
          <p className="text-muted-foreground mt-1">
            Which AI model is generating cached explanations, and how much reuse each gets.
          </p>
        </div>
      </div>

      {rows.length === 0 ? (
        <div className="empty-state py-16">
          <p className="text-muted-foreground">No highlight explanations served yet.</p>
        </div>
      ) : (
        <div className="grid-stats mt-8">
          {rows.map((row) => (
            <div className="card-base p-6" key={row.model_used}>
              <p className="text-sm text-muted-foreground font-mono">{row.model_used}</p>
              <p className="text-2xl font-bold mt-1 text-foreground">{row.total_served}</p>
              <p className="text-xs text-muted-foreground mt-1">
                served across {row.entry_count} cached explanation{row.entry_count !== 1 ? "s" : ""}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
