"use client"

import { Loader2, Rocket } from "lucide-react"
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

interface MissionShipButtonProps {
  passed: number
  total: number
  /** A Check or the final submit is running. */
  isBusy: boolean
  /** The final submit is running ("Grading…"). */
  isGrading: boolean
  onShip: () => void
}

/** Ship ends the mission: the sandbox is torn down and the result opens. Confirms first. */
export function MissionShipButton({ passed, total, isBusy, isGrading, onShip }: MissionShipButtonProps) {
  return (
    <AlertDialog>
      <AlertDialogTrigger asChild>
        <Button className="touch-target-dense gap-1.5" disabled={isBusy} size="sm">
          {isGrading ? (
            <Loader2 aria-hidden className="h-4 w-4 animate-spin" />
          ) : (
            <Rocket aria-hidden className="h-4 w-4" />
          )}
          {isGrading ? "Grading…" : "Ship"}
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Ship your fix?</AlertDialogTitle>
          <AlertDialogDescription>
            {passed} of {total} checks passed on your last Check. Shipping runs one final check of your
            workspace and ends the mission: your sandbox is shut down, the result opens, and you cannot
            come back to this session.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Keep working</AlertDialogCancel>
          <AlertDialogAction onClick={onShip}>Ship</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
