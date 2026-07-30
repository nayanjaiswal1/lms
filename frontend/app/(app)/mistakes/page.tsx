import { Brain } from "lucide-react";
import { getMistakes, getMistakeSummary } from "@/lib/server/mistakes";
import { MistakeTrendChart } from "@/components/mistakes/mistake-trend-chart";
import { MistakeTimeline } from "@/components/mistakes/mistake-timeline";
import { MISTAKE_CATEGORY_OPTIONS } from "@/lib/constants";

export const metadata = { title: "My Mistakes — MindForge" };

export default async function MistakesPage() {
  const [entries, summary] = await Promise.all([getMistakes(), getMistakeSummary()]);

  const categoryLabel: Record<string, string> = Object.fromEntries(
    MISTAKE_CATEGORY_OPTIONS.map((o) => [o.value, o.label]),
  );
  const focusAreas = [...summary]
    .filter((s) => s.trend === "worsening")
    .sort((a, b) => b.total - a.total)
    .slice(0, 2);

  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex items-center gap-3">
          <Brain aria-hidden className="size-6 text-primary" />
          <h1 className="page-title">My Mistakes</h1>
        </div>
        <span className="text-sm text-muted-foreground">
          {entries.length} logged
        </span>
      </div>

      <div className="flex flex-col gap-8">
        <section className="card-base p-6">
          <h2 className="section-title mb-1">Your Growth</h2>
          <p className="mb-4 text-sm text-muted-foreground">
            Mistakes logged per category — a shrinking bar means you&rsquo;re improving.
          </p>

          {focusAreas.length > 0 && (
            <div className="mb-4 flex flex-col gap-2 sm:flex-row sm:gap-3">
              {focusAreas.map((f) => (
                <div className="badge-destructive rounded-lg border px-3 py-2 text-sm" key={f.category}>
                  <span className="font-medium">Focus area:</span>{" "}
                  {categoryLabel[f.category] ?? f.category} ({f.total} recently)
                </div>
              ))}
            </div>
          )}

          <MistakeTrendChart summary={summary} />
        </section>

        <section>
          <h2 className="section-title mb-4">History</h2>
          <MistakeTimeline entries={entries} />
        </section>
      </div>
    </main>
  );
}
