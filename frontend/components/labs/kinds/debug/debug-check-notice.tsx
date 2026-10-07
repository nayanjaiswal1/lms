import { AlertCircle } from "lucide-react"
import { IconMessage } from "@/components/shared/icon-message"
import type { CheckProblem } from "@/hooks/use-debug-check"

interface DebugCheckNoticeProps {
  problem: CheckProblem | null
  message: string | null
}

/** Strip under the toolbar when the last Check could not run. */
export function DebugCheckNotice({ problem, message }: DebugCheckNoticeProps) {
  if (!problem) return null

  return problem === "busy" ? (
    <IconMessage icon={AlertCircle} role="status" variant="strip">
      The grader is busy right now. Try again in a few seconds.
    </IconMessage>
  ) : (
    <IconMessage icon={AlertCircle} role="alert" tone="destructive" variant="strip">
      {message}
    </IconMessage>
  )
}
