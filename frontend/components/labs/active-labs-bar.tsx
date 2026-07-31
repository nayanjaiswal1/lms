"use client"

import { useState } from "react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import { Loader2, Play, Square } from "lucide-react"
import { Button } from "@/components/ui/button"
import { toast } from "sonner"
import { cn } from "@/lib/utils"
import { endLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { useLabProvisioning } from "@/lib/labs/provisioning-context"
import { isLabSessionAlreadyEnded } from "@/lib/labs"
import { LAB_TYPE_ICONS } from "@/lib/labs/lab-type-ui"
import ROUTES, { isProctoredAssessmentRoute } from "@/lib/routes"

const STATUS_LABELS: Record<string, string> = {
  running: "Running",
  paused: "Paused",
}

// Persistent surface for the user's one active lab session — the backend
// allows only one at a time (labs.Service.StartSession). Seeded from the
// server via LabProvisioningProvider's initialSession (getActiveLabSession),
// so a lab left running stays resumable or endable across a page refresh or
// a fresh login, not just something remembered in this browser tab.
// Provisioning sessions are owned by LabProvisioningWatcher's toast instead —
// this only renders once there's something to resume or close. Hidden while
// the user is already on that session's own page — the lab environment there
// has its own end/pause controls, so a duplicate floating bar is just clutter.
//
// Collapses to a status icon by default so it doesn't block content; a tap
// or click opens it to reveal the title and the resume/stop controls. The
// revealed content keeps its natural (non-shrinking) width at all times —
// only the outer shell's max-width animates — so it clips cleanly instead of
// reflowing its text into a tall column while the shell is narrow.
export function ActiveLabsBar() {
  const { session, clear } = useLabProvisioning()
  const [isEnding, setIsEnding] = useState(false)
  const [isExpanded, setIsExpanded] = useState(false)
  const pathname = usePathname()

  if (!session || session.status === "provisioning") return null
  if (pathname === ROUTES.labSession(session.session_id) || isProctoredAssessmentRoute(pathname)) return null

  const Icon = LAB_TYPE_ICONS[session.lab_type]
  const isRunning = session.status === "running"
  const statusLabel = STATUS_LABELS[session.status] ?? session.status

  const handleEnd = async () => {
    setIsEnding(true)
    const result = await endLabSessionAction(session.session_id)
    if (result.error && !isLabSessionAlreadyEnded(result.error)) {
      toast.error(result.error)
      setIsEnding(false)
      return
    }
    clear(session.session_id)
    toast.success("Lab session ended.")
  }

  return (
    <div className="above-bottom-nav fixed inset-x-4 z-sticky mx-auto flex max-w-sm justify-end lg:inset-x-auto lg:right-4">
      <div
        className={cn(
          // Floating fixed pill, not an inline card — needs its own opaque
          // backdrop (bg-card) or whatever's on the page behind it (lesson
          // text, code) shows straight through a translucent .../10 fill.
          // Status color lives in the border/icon/dot instead.
          "flex h-12 items-center overflow-hidden rounded-full border bg-card shadow-raised transition-[max-width,gap,padding-right] duration-normal ease-smooth",
          isRunning ? "border-success/30" : "border-warning/30",
          isExpanded ? "max-w-xs gap-3 px-2 pr-3" : "max-w-12 gap-0 px-2",
        )}
      >
        <button
          aria-expanded={isExpanded}
          aria-label={
            isExpanded
              ? "Collapse lab session controls"
              : `${session.lab_title} lab is ${statusLabel.toLowerCase()} — show controls`
          }
          className="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-card"
          onClick={() => setIsExpanded((expanded) => !expanded)}
          type="button"
        >
          <Icon aria-hidden className={cn("h-4 w-4", isRunning ? "text-success" : "text-warning")} />
          <span
            aria-hidden
            className={cn(
              "absolute -bottom-0.5 -right-0.5 h-2 w-2 rounded-full ring-2",
              isRunning ? "bg-success animate-pulse ring-success/10" : "bg-warning ring-warning/10",
            )}
          />
        </button>

        <div
          className={cn(
            "flex w-56 shrink-0 items-center gap-2 transition-opacity duration-normal ease-smooth",
            isExpanded ? "opacity-100 delay-100" : "pointer-events-none opacity-0",
          )}
        >
          <span className="min-w-0 flex-1 truncate text-sm font-medium text-foreground">{session.lab_title}</span>
          <Button asChild aria-label="Resume lab session" className="touch-target shrink-0" size="icon">
            <Link href={ROUTES.labSession(session.session_id)}>
              <Play aria-hidden className="h-4 w-4" />
            </Link>
          </Button>
          <Button
            aria-label="Stop lab session"
            className="touch-target shrink-0"
            disabled={isEnding}
            onClick={handleEnd}
            size="icon"
            variant="outline"
          >
            {isEnding ? (
              <Loader2 aria-hidden className="h-4 w-4 animate-spin" />
            ) : (
              <Square aria-hidden className="h-4 w-4" />
            )}
          </Button>
        </div>
      </div>
    </div>
  )
}
