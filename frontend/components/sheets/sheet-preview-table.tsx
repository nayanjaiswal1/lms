"use client";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { cn } from "@/lib/utils";
import type { PreviewRow } from "@/lib/sheets/use-sheet-builder";

const DIFFICULTY_CLASS: Record<string, string> = {
  easy: "bg-success/10 text-success border-success/20",
  medium: "bg-warning/10 text-warning border-warning/20",
  hard: "bg-destructive/10 text-destructive border-destructive/20",
};

interface SheetPreviewTableProps {
  rows: PreviewRow[];
  excludedTopics: string[];
  onToggleExclude: (topicTag: string, excluded: boolean) => void;
  onRemoveCustom: (id: string) => void;
}

export function SheetPreviewTable({ rows, excludedTopics, onToggleExclude, onRemoveCustom }: SheetPreviewTableProps) {
  const includedCount = rows.filter(
    (row) => row.isCustom || !excludedTopics.includes(row.topicTag ?? ""),
  ).length;

  return (
    <section className="card-base mt-6 p-6">
      <h2 className="section-title mb-1 text-lg">Preview</h2>
      <p className="mb-3 text-sm text-muted-foreground">
        {includedCount} of {rows.length} questions selected — uncheck any you want left out.
      </p>
      <div className="table-responsive rounded-md border border-border">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs text-muted-foreground">
              <th className="px-3 pb-2 pt-2.5 font-medium">Include</th>
              <th className="px-3 pb-2 pt-2.5 font-medium">Title</th>
              <th className="px-3 pb-2 pt-2.5 font-medium">Topic</th>
              <th className="px-3 pb-2 pt-2.5 font-medium">Difficulty</th>
              <th className="px-3 pb-2 pt-2.5 font-medium">Source</th>
              <th className="px-3 pb-2 pt-2.5 font-medium" />
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {rows.map((row) => {
              const excluded = !row.isCustom && excludedTopics.includes(row.topicTag ?? "");
              const customId = row.customId;
              return (
                <tr className={cn(excluded && "opacity-50")} key={row.key}>
                  <td className="px-3 py-2">
                    {row.isCustom ? (
                      <Checkbox checked disabled aria-label={`${row.title} is always included`} />
                    ) : (
                      <Checkbox
                        aria-label={`Include ${row.title}`}
                        checked={!excluded}
                        onCheckedChange={(checked) => onToggleExclude(row.topicTag ?? "", checked !== true)}
                      />
                    )}
                  </td>
                  <td className={cn("px-3 py-2 font-medium text-foreground", excluded && "line-through")}>
                    {row.title}
                  </td>
                  <td className="px-3 py-2 text-muted-foreground">{row.category ?? "—"}</td>
                  <td className="px-3 py-2">
                    {row.difficulty ? (
                      <Badge className={DIFFICULTY_CLASS[row.difficulty]} variant="outline">
                        {row.difficulty}
                      </Badge>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </td>
                  <td className="px-3 py-2 text-muted-foreground">{row.sourceLabel}</td>
                  <td className="px-3 py-2 text-right">
                    {customId && (
                      <Button
                        aria-label={`Remove ${row.title}`}
                        size="sm"
                        variant="ghost"
                        onClick={() => onRemoveCustom(customId)}
                      >
                        Remove
                      </Button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
