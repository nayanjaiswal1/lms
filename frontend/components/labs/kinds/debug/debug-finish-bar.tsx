"use client"

import { Flag, Loader2 } from "lucide-react"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { useFinishLab } from "@/hooks/use-finish-lab"

interface DebugFinishBarProps {
  sessionId: string
  /** All required tasks passed — Finish only appears enabled then. */
  enabled: boolean
  onAuthExpired: () => void
}

/**
 * Finish ends the session as completed (POST /end), tears the sandbox down
 * and unlocks the debrief. The course module was already credited when the
 * required tasks passed.
 */
export function DebugFinishBar({ sessionId, enabled, onAuthExpired }: DebugFinishBarProps) {
  const { isFinishing, finish } = useFinishLab(sessionId, onAuthExpired)

  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button
          className="touch-target-dense gap-1.5"
          disabled={!enabled || isFinishing}
          size="sm"
          title={enabled ? undefined : "Pass the required checks to finish"}
          variant="outline"
        >
          {isFinishing ? (
            <Loader2 aria-hidden className="h-4 w-4 animate-spin" />
          ) : (
            <Flag aria-hidden className="h-4 w-4" />
          )}
          <span className="max-sm:sr-only">Finish</span>
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Finish this lab?</AlertDialogTitle>
          <AlertDialogDescription>
            Your sandbox is shut down and the debrief opens. Submit your write-up first if you
            want it reviewed. You cannot come back to this session.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Keep working</AlertDialogCancel>
          <AlertDialogAction onClick={finish}>Finish lab</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
