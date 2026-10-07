import { cn } from "@/lib/utils"

interface DebugDiffViewProps {
  title: string
  diff: string
  emptyMessage: string
}

type DiffLineKind = "add" | "remove" | "hunk" | "meta" | "context"

function classify(line: string): DiffLineKind {
  if (line.startsWith("+++") || line.startsWith("---") || line.startsWith("diff ") || line.startsWith("index ")) {
    return "meta"
  }
  if (line.startsWith("@@")) return "hunk"
  if (line.startsWith("+")) return "add"
  if (line.startsWith("-")) return "remove"
  return "context"
}

const LINE_CLASSES: Record<DiffLineKind, string> = {
  add: "bg-success/10 text-success",
  remove: "bg-destructive/10 text-destructive",
  hunk: "bg-muted text-muted-foreground",
  meta: "font-semibold text-muted-foreground",
  context: "text-foreground",
}

/**
 * Accessible unified-diff view: the +/- markers stay in the text (so colour is
 * never the only signal) and the block scrolls horizontally instead of wrapping.
 */
export function DebugDiffView({ title, diff, emptyMessage }: DebugDiffViewProps) {
  const lines = diff.replace(/\n$/, "").split("\n")

  return (
    <figure className="flex min-w-0 flex-col gap-1.5">
      <figcaption className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</figcaption>
      {diff.trim() === "" ? (
        <p className="rounded-md border border-border p-3 text-sm text-muted-foreground">
          {emptyMessage}
        </p>
      ) : (
        <pre
          aria-label={title}
          className="max-h-96 overflow-auto rounded-md border border-border bg-card py-2 font-mono text-xs leading-5"
          // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- keyboard users must be able to focus and scroll a wide diff
          tabIndex={0}
        >
          <code className="block min-w-max">
            {lines.map((line, i) => (
              <span
                className={cn("block whitespace-pre px-3", LINE_CLASSES[classify(line)])}
                // Diff lines have no identity beyond their position.
                key={i}
              >
                {line === "" ? " " : line}
              </span>
            ))}
          </code>
        </pre>
      )}
    </figure>
  )
}
