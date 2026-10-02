import { AlertTriangle, CheckCircle2, Info, XCircle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { IssueSeverity, RecipeAnalysis, UpdateAvailable } from "@/lib/labs/builder/types";

const SEVERITY_ICON: Record<IssueSeverity, { Icon: typeof Info; className: string; label: string }> = {
  error: { Icon: XCircle, className: "text-destructive", label: "Error" },
  warning: { Icon: AlertTriangle, className: "text-warning-foreground", label: "Warning" },
  info: { Icon: Info, className: "text-muted-foreground", label: "Note" },
};

const SEVERITY_ORDER: IssueSeverity[] = ["error", "warning", "info"];

interface ValidationPanelProps {
  analysis: RecipeAnalysis;
  updates: UpdateAvailable[];
}

/** The live validation panel pinned beside every wizard step (docs/debug-labs.md B4). */
export function ValidationPanel({ analysis, updates }: ValidationPanelProps) {
  const issues = [...analysis.issues].sort(
    (a, b) => SEVERITY_ORDER.indexOf(a.severity) - SEVERITY_ORDER.indexOf(b.severity),
  );

  return (
    <aside aria-label="Validation" className="card-base flex flex-col gap-4 lg:sticky lg:top-4">
      <div className="flex items-center gap-2 text-sm font-semibold">
        {analysis.valid ? (
          <CheckCircle2 aria-hidden className="h-4 w-4 text-success" />
        ) : (
          <XCircle aria-hidden className="h-4 w-4 text-destructive" />
        )}
        {analysis.valid ? "Ready to build" : "Not buildable yet"}
      </div>
      <dl className="grid grid-cols-2 gap-2 text-xs">
        <dt className="text-muted-foreground">Difficulty</dt>
        <dd>
          {analysis.difficulty ? (
            <Badge className={cn(`difficulty-${analysis.difficulty}`)} variant="outline">{analysis.difficulty}</Badge>
          ) : (
            "—"
          )}
        </dd>
        <dt className="text-muted-foreground">Variants</dt>
        <dd>
          {analysis.variant_count}
          {analysis.variant_total > analysis.variant_count ? ` of ${analysis.variant_total}` : ""}
        </dd>
      </dl>

      {issues.length > 0 && (
        <ul className="flex flex-col gap-2">
          {issues.map((is, i) => {
            const { Icon, className, label } = SEVERITY_ICON[is.severity];
            return (
              <li className="flex items-start gap-2 text-xs" key={`${is.code}-${is.block}-${i}`}>
                <Icon aria-label={label} className={cn("mt-0.5 h-3.5 w-3.5 shrink-0", className)} />
                <span className="min-w-0 break-words">
                  {is.block && <span className="font-mono text-muted-foreground">{is.block}: </span>}
                  {is.message}
                </span>
              </li>
            );
          })}
        </ul>
      )}

      {updates.length > 0 && (
        <div className="flex flex-col gap-1 border-t border-border pt-3 text-xs">
          <p className="font-semibold">Updates available</p>
          {updates.map((u) => (
            <p className="text-muted-foreground" key={u.block_id}>
              <span className="font-mono">{u.block_key}</span> {u.pinned_version} → {u.latest_version}
            </p>
          ))}
        </div>
      )}
    </aside>
  );
}
