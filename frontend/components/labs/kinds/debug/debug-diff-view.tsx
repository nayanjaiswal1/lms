import { cn } from "@/lib/utils"
import type { DiffRow, DiffRowKind } from "@/lib/labs/kinds/diff"

interface DebugDiffViewProps {
  rows: DiffRow[]
  label: string
  emptyMessage: string
}

const ROW_CLASSES: Record<DiffRowKind, string> = {
  add: "bg-success/10",
  remove: "bg-destructive/10",
  hunk: "bg-muted text-muted-foreground",
  context: "",
}

const MARKERS: Record<DiffRowKind, string> = { add: "+", remove: "-", hunk: "", context: " " }

const MARKER_CLASSES: Record<DiffRowKind, string> = {
  add: "text-success",
  remove: "text-destructive",
  hunk: "",
  context: "",
}

/**
 * One file's diff with line numbers. The +/- markers stay as text so colour is
 * never the only signal; long lines wrap, so nothing is clipped or scrolled sideways.
 */
export function DebugDiffView({ rows, label, emptyMessage }: DebugDiffViewProps) {
  if (rows.length === 0) {
    return <p className="rounded-md border border-border p-3 text-sm text-muted-foreground">{emptyMessage}</p>
  }

  return (
    <div
      aria-label={label}
      className="overflow-hidden rounded-md border border-border bg-card py-1 font-mono text-xs leading-5"
      role="region"
    >
      {rows.map((row, i) => (
        <div
          className={cn("grid grid-cols-[3rem_1.25rem_minmax(0,1fr)]", ROW_CLASSES[row.kind])}
          // Diff rows have no identity beyond their position.
          key={i}
        >
          <span aria-hidden className="select-none pr-2 text-right text-muted-foreground tabular-nums">
            {row.lineNumber}
          </span>
          <span className={cn("select-none font-semibold", MARKER_CLASSES[row.kind])}>{MARKERS[row.kind]}</span>
          <span className={cn("whitespace-pre-wrap break-words pr-3", row.kind === "hunk" && "italic")}>
            {row.kind === "hunk" ? `@@ ${row.text}`.trim() : row.text || " "}
          </span>
        </div>
      ))}
    </div>
  )
}
