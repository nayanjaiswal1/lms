import type { ReleaseMetrics } from "@/lib/workspace/types";

export function ReleaseMetricsSection({ release }: { release: ReleaseMetrics }) {
  return (
    <div className="card-base flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="section-title">Release {release.version}</h2>
        <span className="text-sm text-muted-foreground">{release.status}</span>
      </div>
      <div className="grid-stats">
        <div>
          <p className="text-xs text-muted-foreground">Features</p>
          <p className="text-lg font-semibold">{release.features_done}/{release.features_total}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Days to target</p>
          <p className="text-lg font-semibold">{release.days_to_target ?? "—"}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Docs pending</p>
          <p className="text-lg font-semibold">{release.docs_not_approved}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Scope added after freeze</p>
          <p className="text-lg font-semibold">{release.scope_added_after_freeze}</p>
        </div>
      </div>
      {Object.keys(release.open_bugs_by_severity).length > 0 && (
        <div className="flex flex-wrap gap-2">
          {Object.entries(release.open_bugs_by_severity).map(([sev, count]) => (
            <span className="rounded-sm bg-muted px-2 py-0.5 text-xs" key={sev}>{sev}: {count}</span>
          ))}
        </div>
      )}
    </div>
  );
}
