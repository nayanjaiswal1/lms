"use client"

import { AlertCircle, Loader2, ShieldCheck, TimerReset } from "lucide-react"
import { Button } from "@/components/ui/button"
import { IconMessage } from "@/components/shared/icon-message"
import { useCountdown } from "@/hooks/use-countdown"
import type { CheckProblem } from "@/hooks/use-debug-check"

interface DebugCheckBarProps {
  isChecking: boolean
  /** Epoch ms until which the server refuses another Check. */
  cooldownUntil: number
  problem: CheckProblem | null
  message: string | null
  onCheck: () => void
}

/** The single batch Check: grades the whole workspace in a clean room. */
export function DebugCheckBar({
  isChecking,
  cooldownUntil,
  problem,
  message,
  onCheck,
}: DebugCheckBarProps) {
  const secondsLeft = useCountdown(cooldownUntil)
  const coolingDown = secondsLeft > 0

  return (
    <div className="flex flex-col gap-2">
      <Button
        className="w-full touch-target gap-2"
        disabled={isChecking || coolingDown}
        size="lg"
        onClick={onCheck}
      >
        {isChecking ? (
          <>
            <Loader2 aria-hidden className="h-4 w-4 animate-spin" />
            Checking in a clean room…
          </>
        ) : coolingDown ? (
          <>
            <TimerReset aria-hidden className="h-4 w-4" />
            Check again in {secondsLeft}s
          </>
        ) : (
          <>
            <ShieldCheck aria-hidden className="h-4 w-4" />
            Check my fix
          </>
        )}
      </Button>
      {problem === "busy" && (
        <IconMessage icon={AlertCircle} role="status">
          The grader is busy right now. Try again in a few seconds.
        </IconMessage>
      )}
      {(problem === "error" || problem === "auth") && (
        <IconMessage icon={AlertCircle} role="alert" tone="destructive">
          {message}
        </IconMessage>
      )}
    </div>
  )
}
