import { FileCode2 } from "lucide-react";
import type { FileOwnershipRow } from "@/lib/projects/types";

interface OwnershipTableProps {
  files: FileOwnershipRow[];
}

// Per-file top contributor, aggregated from real change history (no AI) —
// "who to ask about this part of the codebase," not a grading signal.
export function OwnershipTable({ files }: OwnershipTableProps) {
  if (files.length === 0) {
    return (
      <div className="empty-state py-10">
        <FileCode2 aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No file history recorded yet.</p>
      </div>
    );
  }

  return (
    <div className="table-responsive">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-xs text-muted-foreground">
            <th className="py-2 pr-4 font-medium">File</th>
            <th className="py-2 pr-4 font-medium">Owner</th>
            <th className="py-2 font-medium">Changes</th>
          </tr>
        </thead>
        <tbody>
          {files.map((f) => (
            <tr className="whitespace-nowrap border-b border-border last:border-0" key={f.file_path}>
              <td className="py-2 pr-4 font-mono text-xs">{f.file_path}</td>
              <td className="py-2 pr-4">{f.author_name || "Unmatched contributor"}</td>
              <td className="py-2 tabular-nums">{f.change_count}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
