import type { ReactNode } from "react"
import { Clock } from "lucide-react"
import { MISSION_CLOCK_UNKNOWN } from "@/hooks/use-mission-clock"
import { MISSION_WARNING_SECONDS, formatMissionClock } from "@/lib/labs/kinds/debug-mission"
import { cn } from "@/lib/utils"

interface MissionHeaderProps {
  title: string
  /** Seconds to the server deadline; MISSION_CLOCK_UNKNOWN until measured, null before Start. */
  secondsLeft: number | null
  /** Check, Ship, Reset, rail toggle. */
  actions: ReactNode
}

/** Slim mission bar: mission caption + title, the countdown, then the actions. */
export function MissionHeader({ title, secondsLeft, actions }: MissionHeaderProps) {
  const known = secondsLeft !== null && secondsLeft !== MISSION_CLOCK_UNKNOWN
  const warning = known && secondsLeft <= MISSION_WARNING_SECONDS

  return (
    <header className="flex h-12 shrink-0 items-center gap-3 border-b border-border bg-card px-3">
      <div className="min-w-0 flex-1 leading-tight">
        <p className="font-mono text-xs uppercase tracking-wider text-primary">Mission · Debug</p>
        <h1 className="truncate text-sm font-semibold">{title}</h1>
      </div>
      <div
        aria-label={known ? `Time remaining: ${formatMissionClock(secondsLeft)}` : "Mission not started"}
        className="flex flex-col items-end leading-none"
      >
        <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">Time left</span>
        <span
          className={cn(
            "flex items-center gap-1 font-mono text-xl font-semibold tabular-nums",
            warning ? "text-destructive" : "text-foreground",
          )}
        >
          <Clock aria-hidden className="h-4 w-4 text-muted-foreground" />
          {known ? formatMissionClock(secondsLeft) : "--:--"}
        </span>
      </div>
      <div className="flex shrink-0 items-center gap-1.5">{actions}</div>
    </header>
  )
}
