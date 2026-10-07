import { AlertTriangle, CheckCircle2, ChevronDown, Info, XCircle } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { UpdateList } from "@/components/labs/builder/update-list";
import type { RecipeRef } from "@/components/labs/builder/use-save-spec";
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
  recipe: RecipeRef;
}

/** Compact, collapsible validation summary above every wizard step (docs/debug-labs.md B4). */
export function ValidationPanel({ analysis, updates, recipe }: ValidationPanelProps) {
  const issues = [...analysis.issues].sort(
    (a, b) => SEVERITY_ORDER.indexOf(a.severity) - SEVERITY_ORDER.indexOf(b.severity),
  );
  const count = (s: IssueSeverity) => issues.filter((i) => i.severity === s).length;
  const expandable = issues.length > 0 || updates.length > 0;

  return (
    <details className="group rounded-lg border border-border bg-card text-sm" open={!analysis.valid && expandable}>
      <summary className="touch-target flex cursor-pointer list-none flex-wrap items-center gap-x-3 gap-y-1 px-4 py-2">
        {analysis.valid ? (
          <CheckCircle2 aria-hidden className="h-4 w-4 text-success" />
        ) : (
          <XCircle aria-hidden className="h-4 w-4 text-destructive" />
        )}
        <span className="font-medium">{analysis.valid ? "Ready to build" : "Not buildable yet"}</span>
        {count("error") > 0 && <Badge className="badge-destructive" variant="outline">{count("error")} errors</Badge>}
        {count("warning") > 0 && <Badge className="badge-warning" variant="outline">{count("warning")} warnings</Badge>}
        {updates.length > 0 && <Badge className="badge-info" variant="outline">{updates.length} updates</Badge>}
        <span className="ml-auto flex items-center gap-3 text-xs text-muted-foreground">
          {analysis.difficulty && <Badge className={cn(`difficulty-${analysis.difficulty}`)} variant="outline">{analysis.difficulty}</Badge>}
          <span>
            {analysis.variant_count}
            {analysis.variant_total > analysis.variant_count ? ` of ${analysis.variant_total}` : ""} variants
          </span>
          {expandable && <ChevronDown aria-hidden className="h-4 w-4 transition-transform group-open:rotate-180" />}
        </span>
      </summary>
      {expandable && (
        <div className="flex flex-col gap-3 border-t border-border px-4 py-3">
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
          {updates.length > 0 && <UpdateList recipe={recipe} updates={updates} />}
        </div>
      )}
    </details>
  );
}
