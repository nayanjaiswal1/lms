import { LineChart } from "lucide-react";
import { ChapterMasteryHeatmap } from "@/components/batches/chapter-mastery-heatmap";
import { ChapterHintBarChart } from "@/components/batches/chapter-hint-bar-chart";
import { BlockersBreakdown } from "@/components/batches/blockers-breakdown";
import { EngagementScatterChart } from "@/components/batches/engagement-scatter-chart";
import { getBatchAnalytics, type BatchAnalytics } from "@/lib/server/batches";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";

interface Props {
  params: Promise<{ id: string }>;
}

const EMPTY_ANALYTICS: BatchAnalytics = {
  health: { total_students: 0, on_track_pct: 0, needs_support_pct: 0, not_engaged_pct: 0 },
  roster: [],
  chapter_mastery: [],
  chapter_hint_ranking: [],
  blockers: { buckets: [], estimated: true },
  engagement: [],
};

export default async function BatchAnalyticsPage({ params }: Props) {
  const { id } = await params;
  const [analytics, orgType] = await Promise.all([
    getBatchAnalytics(id).catch(() => EMPTY_ANALYTICS),
    getCurrentOrgType(),
  ]);
  const t = resolveTerminology(orgType);

  return (
    <section className="flex flex-col gap-8">
      <div className="flex items-center gap-2">
        <LineChart aria-hidden className="h-5 w-5 text-muted-foreground" />
        <h2 className="section-title">{t.class_} Analytics</h2>
      </div>

      <div className="card-base p-6">
        <h3 className="text-base font-semibold mb-1">Chapter Mastery</h3>
        <p className="text-sm text-muted-foreground mb-4">
          Colored by average hints used per chapter — green is low reliance, red is high.
        </p>
        <ChapterMasteryHeatmap cells={analytics.chapter_mastery} t={t} />
      </div>

      <div className="grid-responsive-2 gap-6">
        <div className="card-base p-6">
          <h3 className="text-base font-semibold mb-1">Weakest / Strongest Chapters</h3>
          <p className="text-sm text-muted-foreground mb-4">Ranked by average hints requested per chapter.</p>
          <ChapterHintBarChart stats={analytics.chapter_hint_ranking} />
        </div>

        <div className="card-base p-6">
          <h3 className="text-base font-semibold mb-1">Where Students Get Stuck</h3>
          <p className="text-sm text-muted-foreground mb-4">Breakdown of hint requests by type.</p>
          <BlockersBreakdown data={analytics.blockers} />
        </div>
      </div>

      <div className="card-base p-6">
        <h3 className="text-base font-semibold mb-1">Progress vs Engagement</h3>
        <p className="text-sm text-muted-foreground mb-4">
          Problems solved against days active — spot who needs a nudge.
        </p>
        <EngagementScatterChart points={analytics.engagement} />
      </div>
    </section>
  );
}
