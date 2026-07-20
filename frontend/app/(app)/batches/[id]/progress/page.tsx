import { BarChart3 } from "lucide-react";
import { BatchProgressTable } from "@/components/batches/batch-progress-table";
import { ClassHealthWidgets } from "@/components/batches/class-health-widgets";
import { getBatchAnalytics } from "@/lib/server/batches";
import { getCurrentOrgType } from "@/lib/orgs/server";
import { resolveTerminology } from "@/lib/terminology";
import type { BatchAnalytics } from "@/lib/server/batches";

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

export default async function BatchProgressPage({ params }: Props) {
  const { id } = await params;
  const [analytics, orgType] = await Promise.all([
    getBatchAnalytics(id).catch(() => EMPTY_ANALYTICS),
    getCurrentOrgType(),
  ]);
  const t = resolveTerminology(orgType);

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center gap-2">
        <BarChart3 aria-hidden className="h-5 w-5 text-muted-foreground" />
        <h2 className="section-title">{t.class_} Health</h2>
      </div>
      <ClassHealthWidgets health={analytics.health} t={t} />
      <BatchProgressTable progress={analytics.roster} t={t} />
    </section>
  );
}
