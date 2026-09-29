import { XCircle } from "lucide-react"
import type { CheckFailure } from "@/lib/labs/kinds/debug-results"

interface DebugFailureListProps {
  failures: CheckFailure[]
}

/** Failing checks from the last Check, as the grader's author messages. */
export function DebugFailureList({ failures }: DebugFailureListProps) {
  if (failures.length === 0) return null

  return (
    <ul aria-label="Failing checks" className="mt-1 flex flex-col gap-1.5">
      {failures.map((f) => (
        <li className="flex items-start gap-1.5 text-xs" key={`${f.name}:${f.message}`}>
          <XCircle aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0 text-destructive" />
          <span className="min-w-0 break-words">
            <span className="font-mono font-medium text-foreground">{f.name}</span>
            <span className="text-muted-foreground"> — {f.message}</span>
          </span>
        </li>
      ))}
    </ul>
  )
}
