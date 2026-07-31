"use client"

import { useRouter } from "next/navigation"
import { Terminal, Clock, CheckSquare, Loader2, LogOut } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { LabReadinessWait } from "@/components/labs/lab-readiness-wait"
import { LabTimer } from "@/components/labs/lab-timer"
import { useLessonLab } from "@/components/courses/lesson-lab-provider"

// Rendered once, immediately before the first [[lab-task:N]] marker in the
// lesson body — the Google Cloud Skills Boost equivalent of the top
// "instance details" panel that precedes the per-task check cards.
export function LessonLabHero() {
  const router = useRouter()
  const {
    lab,
    initialSession,
    isStarting,
    isEnding,
    isOtherLabActive,
    handleStart,
    handleEnd,
  } = useLessonLab()

  if (initialSession?.session.status === "provisioning") {
    return (
      <LabReadinessWait
        sessionId={initialSession.session.id}
        onFailed={() => router.refresh()}
        onReady={() => router.refresh()}
      />
    )
  }

  // Once running, the actual workspace renders in <LessonLabWorkspacePane> —
  // a grid sibling ModuleNotes places next to the lesson body — so this hero
  // shrinks to just the status header (title, timer, End Lab).
  if (
    initialSession &&
    (initialSession.session.status === "running" || initialSession.session.status === "paused")
  ) {
    return (
      <header className="app-subheader flex h-12 shrink-0 items-center justify-between gap-3 rounded-lg border border-border bg-card px-4">
        <span className="truncate text-sm font-semibold text-foreground">{lab.title}</span>
        <div className="flex shrink-0 items-center gap-3">
          <LabTimer expiresAt={initialSession.session.expires_at} onExpired={handleEnd} />
          <Button disabled={isEnding} size="sm" variant="outline" onClick={handleEnd}>
            <LogOut aria-hidden className="h-3.5 w-3.5" />
            {isEnding ? "Ending…" : "End Lab"}
          </Button>
        </div>
      </header>
    )
  }

  const totalPoints = lab.tasks.reduce((s, t) => s + t.points, 0)

  return (
    <div className="card-base flex flex-col gap-4 p-5">
      <div className="flex flex-wrap items-center gap-2">
        <Badge className="capitalize" variant="outline">{lab.lab_type}</Badge>
        <Badge variant="secondary">
          <Clock aria-hidden className="mr-1 h-3 w-3" />{lab.max_duration} min
        </Badge>
        <Badge variant="secondary">
          <CheckSquare aria-hidden className="mr-1 h-3 w-3" />{lab.tasks.length} tasks
        </Badge>
        {totalPoints > 0 && <Badge variant="secondary">{totalPoints} pts</Badge>}
      </div>
      <div className="flex flex-col gap-1">
        <h3 className="text-lg font-semibold text-foreground">{lab.title}</h3>
        {lab.description && (
          <p className="text-sm leading-relaxed text-muted-foreground">{lab.description}</p>
        )}
      </div>
      <Button className="w-full sm:w-auto" disabled={isStarting} onClick={handleStart}>
        {isStarting ? (
          <Loader2 aria-hidden className="mr-2 h-4 w-4 animate-spin" />
        ) : (
          <Terminal aria-hidden className="mr-2 h-4 w-4" />
        )}
        {isStarting ? "Starting…" : isOtherLabActive ? "Another lab is active" : "Launch Lab"}
      </Button>
    </div>
  )
}
