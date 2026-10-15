"use client"

import { RotateCcw } from "lucide-react"
import { Button } from "@/components/ui/button"
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
import { cn } from "@/lib/utils"

interface LabResetButtonProps {
  resetsLeft: number
  /** Any in-flight session action (ending or resetting) disables the button. */
  busy: boolean
  isResetting: boolean
  className?: string
  onReset: () => void
}

/** Quiet icon action that confirms before resetting the lab; hidden once no resets are left. */
export function LabResetButton({ resetsLeft, busy, isResetting, className, onReset }: LabResetButtonProps) {
  if (resetsLeft <= 0) return null
  const plural = resetsLeft !== 1 ? "s" : ""
  const label = `Reset lab (${resetsLeft} reset${plural} left)`

  return (
    <AlertDialog>
      <Tooltip>
        <TooltipTrigger asChild>
          <AlertDialogTrigger asChild>
            <Button
              aria-label={label}
              className={cn("text-muted-foreground hover:text-foreground", className)}
              disabled={busy}
              size="icon"
              variant="ghost"
            >
              <RotateCcw aria-hidden />
            </Button>
          </AlertDialogTrigger>
        </TooltipTrigger>
        <TooltipContent>{label}</TooltipContent>
      </Tooltip>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Reset this lab?</AlertDialogTitle>
          <AlertDialogDescription>
            All task completions and your score will be cleared. Your code in the editor will also
            reset. This uses one of your {resetsLeft} remaining reset{plural} — this action cannot be
            undone.
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
  )
}
