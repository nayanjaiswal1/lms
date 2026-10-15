"use client"

import { useState, useSyncExternalStore, type CSSProperties } from "react"
import { Check, Loader2, ShieldCheck } from "lucide-react"
import { MISSION_BUILD_STEPS } from "@/lib/labs/kinds/debug-mission"
import { cn } from "@/lib/utils"

// The bar tops out here until the real ready signal arrives.
const PROGRESS_CEILING_PERCENT = 95
// Seconds at which the estimate reaches the ceiling (a typical cold start).
const ESTIMATE_SECONDS = 40

function subscribe(listener: () => void): () => void {
  const id = setInterval(listener, 1000)
  return () => clearInterval(id)
}

interface MissionBuildScreenProps {
  title: string
}

/**
 * Full-screen "Building your mission" shown while the sandbox provisions, for
 * orgs on the new debug UI. Step and bar advance with elapsed time (an
 * estimate); the screen itself disappears on the real ready signal.
 */
export function MissionBuildScreen({ title }: MissionBuildScreenProps) {
  const [startedAt] = useState(() => Date.now())
  const elapsed = useSyncExternalStore(
    subscribe,
    () => Math.floor((Date.now() - startedAt) / 1000),
    () => 0,
  )
  const current = MISSION_BUILD_STEPS.findLastIndex((step) => elapsed >= step.atSeconds)
  const percent = Math.min(PROGRESS_CEILING_PERCENT, Math.round((elapsed / ESTIMATE_SECONDS) * 100))

  return (
    <div className="relative z-raised flex h-full flex-col items-center justify-center gap-6 px-6 text-center">
      <div className="flex flex-col items-center gap-2">
        <h1 className="text-3xl font-semibold tracking-tight">
          Building your <span className="text-primary">mission</span>
        </h1>
        <p className="max-w-md truncate text-sm text-muted-foreground">{title}</p>
      </div>

      <ol aria-live="polite" className="flex w-full max-w-xs flex-col gap-3 text-left">
        {MISSION_BUILD_STEPS.map((step, index) => {
          const done = index < current
          const active = index === current
          return (
            <li
              className={cn("flex items-center gap-3 text-sm", !done && !active && "text-muted-foreground")}
              key={step.label}
            >
              <span
                aria-hidden
                className={cn(
                  "flex h-5 w-5 shrink-0 items-center justify-center rounded-full border",
                  done ? "border-primary bg-primary text-primary-foreground" : "border-border",
                  active && "border-primary",
                )}
              >
                {done && <Check className="h-3 w-3" />}
                {active && <Loader2 className="h-3 w-3 animate-spin text-primary" />}
              </span>
              {step.label}
            </li>
          )
        })}
      </ol>

      <div aria-hidden className="progress-track w-full max-w-xs">
        <div className="progress-fill" style={{ "--progress": `${percent}%` } as CSSProperties} />
      </div>

      <p className="flex items-center gap-2 text-xs text-muted-foreground">
        <ShieldCheck aria-hidden className="h-3.5 w-3.5" />
        Your attempt runs in its own isolated sandbox.
      </p>
    </div>
  )
}
