"use client"

import { Lightbulb, Loader2, Sparkles, TriangleAlert } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "@/lib/utils"
import type { LabTask } from "@/lib/labs"
import type { RevealedHint } from "@/hooks/use-lab-hint"

interface HintDrawerProps {
  task: LabTask | undefined
  open: boolean
  revealedHints: RevealedHint[]
  hintsUsed: number
  maxHints: number
  hintPenaltyPct: number
  isRequesting: boolean
  error: string | null
  onRequestHint: () => void
  onOpenChange: (open: boolean) => void
}

// HintDrawer — AI content, so .ai-surface/.ai-badge (cyan), never amber
// (frontend/CLAUDE.md's amber-is-human / cyan-is-AI rule). Each POST
// .../hint call always advances one level (1 -> 2 -> 3); this only ever
// shows a "get the next hint" action, never a level picker.
export function HintDrawer({
  task,
  open,
  revealedHints,
  hintsUsed,
  maxHints,
  hintPenaltyPct,
  isRequesting,
  error,
  onRequestHint,
  onOpenChange,
}: HintDrawerProps) {
  const exhausted = hintsUsed >= maxHints
  const nextLevel = hintsUsed + 1

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="flex flex-col gap-4" side="right">
        <SheetHeader className="shrink-0">
          <SheetTitle className="flex items-center gap-2">
            <Sparkles aria-hidden className="h-4 w-4 text-ai" />
            Hints
          </SheetTitle>
          <SheetDescription>
            {task ? task.title : "Select a task to get a hint."}
          </SheetDescription>
        </SheetHeader>

        <div className="flex items-center justify-between shrink-0">
          <span className="text-xs font-medium text-muted-foreground">
            {hintsUsed}/{maxHints} hints used
          </span>
          {hintPenaltyPct > 0 && (
            <Badge className="ai-badge" variant="outline">
              -{hintPenaltyPct}% per hint
            </Badge>
          )}
        </div>

        <ScrollArea className="flex-1 min-h-0">
          <div className="flex flex-col gap-3 pr-2">
            {revealedHints.length === 0 && (
              <p className="text-sm text-muted-foreground">
                No hints revealed yet for this task.
              </p>
            )}
            {revealedHints.map((hint) => (
              <div className="ai-surface flex flex-col gap-1.5 p-4" key={hint.level}>
                <div className="flex items-center gap-1.5">
                  <Lightbulb aria-hidden className="h-3.5 w-3.5 text-ai shrink-0" />
                  <span className="text-xs font-semibold text-ai">Hint {hint.level}</span>
                </div>
                <p className="text-sm text-foreground leading-relaxed whitespace-pre-wrap">
                  {hint.content}
                </p>
              </div>
            ))}
          </div>
        </ScrollArea>

        {error && (
          <p className="text-sm text-destructive shrink-0" role="alert">
            {error}
          </p>
        )}

        <div className="flex flex-col gap-2 border-t border-border pt-4 shrink-0">
          {!exhausted && hintPenaltyPct > 0 && (
            <p className="flex items-start gap-1.5 text-xs text-muted-foreground">
              <TriangleAlert aria-hidden className="h-3.5 w-3.5 shrink-0 text-warning-foreground" />
              Revealing hint {nextLevel} will dock {hintPenaltyPct}% of this task&apos;s points if
              you pass it.
            </p>
          )}
          <Button
            className={cn("gap-1.5")}
            disabled={!task || exhausted || isRequesting}
            variant="outline"
            onClick={onRequestHint}
          >
            {isRequesting ? (
              <>
                <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                Getting hint…
              </>
            ) : exhausted ? (
              "No more hints for this task"
            ) : (
              `Get hint ${nextLevel} of ${maxHints}`
            )}
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  )
}
