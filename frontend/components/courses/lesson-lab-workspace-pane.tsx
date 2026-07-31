"use client"

import { useRouter } from "next/navigation"
import { LogOut } from "lucide-react"
import { Button } from "@/components/ui/button"
import { LabTimer } from "@/components/labs/lab-timer"
import { LabWorkspaceContent } from "@/components/labs/lab-workspace-content"
import { useLessonLab } from "@/components/courses/lesson-lab-provider"
import ROUTES from "@/lib/routes"

// Split-view counterpart to LessonLabHero: the actual task panel + editor/
// terminal, in its own sticky grid cell next to the lesson body instead of
// inline with it. Keeps a duplicate timer/End Lab header so both stay usable
// once the notes column scrolls past the (non-sticky) hero header above it.
export function LessonLabWorkspacePane() {
  const router = useRouter()
  const { lab, initialSession, isEnding, handleEnd, setVerifyBridge } = useLessonLab()

  if (!initialSession) return null

  return (
    <div className="flex h-[70dvh] flex-col overflow-hidden rounded-lg border border-border bg-card lg:sticky-rail lg:top-8 lg:h-[calc(100dvh-6rem)]">
      <header className="flex h-12 shrink-0 items-center justify-between gap-3 border-b border-border px-4">
        <span className="truncate text-sm font-semibold text-foreground">{lab.title}</span>
        <div className="flex shrink-0 items-center gap-3">
          <LabTimer expiresAt={initialSession.session.expires_at} onExpired={handleEnd} />
          <Button disabled={isEnding} size="sm" variant="outline" onClick={handleEnd}>
            <LogOut aria-hidden className="h-3.5 w-3.5" />
            {isEnding ? "Ending…" : "End Lab"}
          </Button>
        </div>
      </header>
      <LabWorkspaceContent
        hideTaskChecklist
        consoleMode="fixed"
        initialCompletions={initialSession.task_completions}
        lab={lab}
        session={initialSession.session}
        onLogin={() => router.push(ROUTES.LOGIN)}
        onVerifyStateChange={setVerifyBridge}
      />
    </div>
  )
}
