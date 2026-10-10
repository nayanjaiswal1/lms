"use client"

import { RotateCcw, LogOut, Trophy, Columns2, Rows2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import {
  AlertDialog,
  AlertDialogTrigger,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
  AlertDialogAction,
} from "@/components/ui/alert-dialog"
import { LabTimer } from "@/components/labs/lab-timer"

interface LabEnvironmentTopBarProps {
  labTitle: string
  labType: string
  maxResets: number
  expiresAt: string
  score: number
  maxScore: number
  resetCount: number
  isPending: boolean
  isResetting: boolean
  layoutOrientation: "horizontal" | "vertical"
  onEnd: () => void
  onExpired: () => void
  onReset: () => void
  onToggleLayout: () => void
}

/** Lab session header. Reset is a quiet icon action; End Lab is the one labelled, bordered action. */
export function LabEnvironmentTopBar({
  labTitle,
  labType,
  maxResets,
  expiresAt,
  score,
  maxScore,
  resetCount,
  isPending,
  isResetting,
  layoutOrientation,
  onEnd,
  onExpired,
  onReset,
  onToggleLayout,
}: LabEnvironmentTopBarProps) {
  const resetsLeft = maxResets - resetCount
  const resetLabel = `Reset lab (${resetsLeft} reset${resetsLeft !== 1 ? "s" : ""} left)`
  const busy = isPending || isResetting

  return (
    <header className="h-14 shrink-0 flex-between gap-3 px-4 border-b border-border bg-card">
      <div className="flex items-center gap-2 min-w-0">
        <span className="font-semibold text-sm truncate text-foreground">{labTitle}</span>
        <Badge className="capitalize shrink-0 hidden sm:inline-flex text-xs" variant="outline">
          {labType}
        </Badge>
      </div>

      <div className="shrink-0">
        <LabTimer expiresAt={expiresAt} onExpired={onExpired} />
      </div>

      <div className="flex items-center gap-1 shrink-0">
        {maxScore > 0 && (
          <div
            aria-label={`Score: ${score} of ${maxScore} points`}
            className="hidden sm:flex items-center gap-1 mr-2 text-xs tabular-nums text-muted-foreground"
          >
            <Trophy aria-hidden className="h-3.5 w-3.5 text-primary shrink-0" />
            <span>
              {score}/{maxScore}
            </span>
          </div>
        )}

        <Button
          aria-label={
            layoutOrientation === "horizontal"
              ? "Switch to stacked layout"
              : "Switch to side-by-side layout"
          }
          className="min-h-11 min-w-11 text-muted-foreground hover:text-foreground hidden md:inline-flex"
          size="icon"
          variant="ghost"
          onClick={onToggleLayout}
        >
          {layoutOrientation === "horizontal" ? <Rows2 aria-hidden /> : <Columns2 aria-hidden />}
        </Button>

        {resetsLeft > 0 && (
          <AlertDialog>
            <Tooltip>
              <TooltipTrigger asChild>
                <AlertDialogTrigger asChild>
                  <Button
                    aria-label={resetLabel}
                    className="min-h-11 min-w-11 text-muted-foreground hover:text-foreground"
                    disabled={busy}
                    size="icon"
                    variant="ghost"
                  >
                    <RotateCcw aria-hidden />
                  </Button>
                </AlertDialogTrigger>
              </TooltipTrigger>
              <TooltipContent>{resetLabel}</TooltipContent>
            </Tooltip>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Reset this lab?</AlertDialogTitle>
                <AlertDialogDescription>
                  All task completions and your score will be cleared. Your code in the editor will
                  also reset. This uses one of your {resetsLeft} remaining reset
                  {resetsLeft !== 1 ? "s" : ""} — this action cannot be undone.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  onClick={onReset}
                >
                  {isResetting ? "Resetting…" : "Reset Lab"}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        )}

        <div className="ml-2 border-l border-border pl-3">
          <Button
            aria-label="End lab session"
            className="min-h-11 border-destructive/60 text-destructive hover:bg-destructive/10 hover:text-destructive"
            disabled={busy}
            variant="outline"
            onClick={onEnd}
          >
            <LogOut aria-hidden />
            <span className="max-sm:sr-only">{isPending ? "Ending…" : "End Lab"}</span>
          </Button>
        </div>
      </div>
    </header>
  )
}
