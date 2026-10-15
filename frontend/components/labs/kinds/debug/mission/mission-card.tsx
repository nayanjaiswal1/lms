import type { ReactNode } from "react"
import { cn } from "@/lib/utils"

interface MissionCardProps {
  /** Small mono caption (ALERT, MISSION, LIVE STATUS). */
  label: string
  /** Right end of the caption row (a status chip, a toggle). */
  aside?: ReactNode
  tone?: "default" | "alert"
  children: ReactNode
}

/** One dense card of the mission rail: caption row, then content. */
export function MissionCard({ label, aside, tone = "default", children }: MissionCardProps) {
  return (
    <section
      aria-label={label}
      className={cn(
        "flex flex-col gap-2 rounded-lg border p-3",
        tone === "alert" ? "border-destructive/40 bg-destructive/5" : "border-border bg-card",
      )}
    >
      <header className="flex items-center justify-between gap-2">
        <h2
          className={cn(
            "font-mono text-xs font-medium uppercase tracking-wider",
            tone === "alert" ? "text-destructive" : "text-muted-foreground",
          )}
        >
          {label}
        </h2>
        {aside}
      </header>
      {children}
    </section>
  )
}
