import { AlertCircle } from "lucide-react"
import { IconMessage } from "@/components/shared/icon-message"
import { Button } from "@/components/ui/button"
import type { CheckProblem } from "@/hooks/use-debug-check"

interface DebugCheckNoticeProps {
  problem: CheckProblem | null
  message: string | null
  onRetry: () => void
}

/** Strip under the toolbar when the last Check could not run. */
export function DebugCheckNotice({ problem, message, onRetry }: DebugCheckNoticeProps) {
  if (!problem) return null

  const retry =
    problem === "auth" ? null : (
      <Button className="ml-2" size="sm" variant="outline" onClick={onRetry}>
        Try again
      </Button>
    )

  return problem === "busy" ? (
    <IconMessage icon={AlertCircle} role="status" variant="strip">
      The grader is busy right now. Try again in a few seconds.
      {retry}
    </IconMessage>
  ) : (
    <IconMessage icon={AlertCircle} role="alert" tone="destructive" variant="strip">
      {message}
      {retry}
    </IconMessage>
  )
}
