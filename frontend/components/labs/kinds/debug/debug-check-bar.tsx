"use client"

import { Loader2, ShieldCheck, TimerReset } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useCountdown } from "@/hooks/use-countdown"

interface DebugCheckBarProps {
  isChecking: boolean
  /** Epoch ms until which the server refuses another Check. */
  cooldownUntil: number
  onCheck: () => void
}

/** The single batch Check: grades the whole workspace in a clean room. */
export function DebugCheckBar({ isChecking, cooldownUntil, onCheck }: DebugCheckBarProps) {
  const secondsLeft = useCountdown(cooldownUntil)
  const coolingDown = secondsLeft > 0

  return (
    <Button
      className="touch-target-dense gap-1.5"
      disabled={isChecking || coolingDown}
      size="sm"
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
          {secondsLeft}s
        </>
      ) : (
        <>
          <ShieldCheck aria-hidden className="h-4 w-4" />
          Check my fix
        </>
      )}
    </Button>
  )
}
