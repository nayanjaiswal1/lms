import { Badge } from "@/components/ui/badge";
import type { Quality } from "@/lib/workspace/types";

const SEVERITY_BADGE: Record<string, string> = {
  S1: "badge-destructive",
  S2: "badge-warning",
  S3: "badge-muted",
  S4: "badge-muted",
};

interface QualitySectionProps {
  quality: Quality;
}

export function QualitySection({ quality }: QualitySectionProps) {
  return (
    <div className="card-base flex flex-col gap-4">
      <h2 className="section-title">Quality</h2>

      <div className="flex flex-wrap gap-2">
        {quality.bugs_by_severity.length === 0 ? (
          <p className="text-sm text-muted-foreground">No open bugs.</p>
        ) : (
          quality.bugs_by_severity.map((sc) => (
            <Badge className={SEVERITY_BADGE[sc.severity]} key={sc.severity} variant="outline">
              {sc.severity}: {sc.open} open (oldest {Math.round(sc.oldest_age_hours)}h)
            </Badge>
          ))
        )}
      </div>

      <div className="grid-stats">
        <div>
          <p className="text-xs text-muted-foreground">Reopen rate</p>
          <p className="text-lg font-semibold">{quality.reopen_rate_pct.toFixed(0)}%</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Escaped bugs</p>
          <p className="text-lg font-semibold">{quality.escaped_bugs}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">CI pass rate</p>
          <p className="text-lg font-semibold">{quality.ci_pass_rate_pct !== null ? `${quality.ci_pass_rate_pct.toFixed(0)}%` : "—"}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Large MRs</p>
          <p className="text-lg font-semibold">{quality.large_mrs}</p>
        </div>
      </div>
    </div>
  );
}
