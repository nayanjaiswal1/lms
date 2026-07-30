import { Code } from "lucide-react";

import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { ProjectOriginalityMatch } from "@/lib/projects/types";

interface OriginalityMatchRowProps {
  match: ProjectOriginalityMatch;
  teamsById: Record<string, string>;
}

// A single 0–1 Jaccard similarity per row is a magnitude, not a category —
// per the dataviz skill's form heuristic this is an inline meter (reusing
// globals.css's .progress-track/.progress-fill), not a chart. Color is a
// status encoding (concern level), not sequential magnitude: every match
// here already crossed the backend's 0.6 report threshold (originality.go's
// originalityMatchThreshold), so the meaningful split is "flagged" (warning)
// vs. "near-duplicate" (destructive) rather than a smooth low->high ramp.
function similarityBand(similarity: number): "warning" | "destructive" {
  return similarity >= 0.85 ? "destructive" : "warning";
}

export function OriginalityMatchRow({ match, teamsById }: OriginalityMatchRowProps) {
  const teamAName = teamsById[match.team_a_id] ?? match.team_a_id;
  const teamBName = match.team_b_id ? (teamsById[match.team_b_id] ?? match.team_b_id) : "Template";
  const pct = Math.round(match.similarity * 100);
  const band = similarityBand(match.similarity);

  return (
    <tr className="border-b border-border last:border-0">
      <td className="whitespace-nowrap py-2 pr-4 align-top text-sm">
        <span className="font-medium">{teamAName}</span>
        <span className="mx-1.5 text-muted-foreground">vs</span>
        <span className="font-medium">{teamBName}</span>
      </td>
      <td className="py-2 pr-4 align-top font-mono text-xs text-muted-foreground">
        <div>{match.file_path_a}</div>
        <div>{match.file_path_b}</div>
      </td>
      <td className="py-2 pr-4 align-top">
        <div className="flex w-full items-center gap-2 sm:w-40">
          <div className="progress-track">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic similarity width needs inline style */}
            <div className={cn("progress-fill", `progress-fill-${band}`)} style={{ width: `${pct}%` }} />
          </div>
          <span className="shrink-0 text-xs tabular-nums text-muted-foreground">{pct}%</span>
        </div>
        {match.matched_lines !== null && (
          <span className="text-xs text-muted-foreground">{match.matched_lines} matched lines</span>
        )}
      </td>
      <td className="py-2 align-top">
        {match.sample ? (
          <Popover>
            <PopoverTrigger asChild>
              <Button size="sm" variant="ghost">
                <Code aria-hidden className="mr-1.5 h-3.5 w-3.5" />
                View sample
              </Button>
            </PopoverTrigger>
            <PopoverContent align="start" className="w-full sm:w-96">
              <pre className="max-h-64 overflow-auto whitespace-pre-wrap font-mono text-xs">{match.sample}</pre>
            </PopoverContent>
          </Popover>
        ) : (
          <span className="text-xs text-muted-foreground">—</span>
        )}
      </td>
    </tr>
  );
}
