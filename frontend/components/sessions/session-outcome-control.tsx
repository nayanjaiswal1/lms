"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
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
} from "@/components/ui/alert-dialog";
import { setSessionOutcomeAction, type SessionStatus } from "@/lib/server/sessions";

interface SessionOutcomeControlProps {
  sessionId: string;
  status: SessionStatus;
  startsAt: string;
}

export function SessionOutcomeControl({ sessionId, status, startsAt }: SessionOutcomeControlProps) {
  const [pending, setPending] = useState<"completed" | "no_show" | null>(null);
  const router = useRouter();

  // Defensive guard — mirrors what the parent already checks: only a
  // scheduled session whose start time has passed can be closed out.
  if (status !== "scheduled" || new Date(startsAt).getTime() > Date.now()) return null;

  async function setOutcome(next: "completed" | "no_show") {
    setPending(next);
    const result = await setSessionOutcomeAction(sessionId, next);
    setPending(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(next === "completed" ? "Session marked completed." : "Session marked as a no-show.");
    router.refresh();
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Button disabled={pending !== null} onClick={() => void setOutcome("completed")}>
        {pending === "completed" ? "Saving…" : "Mark completed"}
      </Button>
      <AlertDialog>
        <AlertDialogTrigger asChild>
          <Button disabled={pending !== null} variant="outline">
            Mark no-show
          </Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Mark this session as a no-show?</AlertDialogTitle>
            <AlertDialogDescription>
              This records that the other party did not attend. It cannot be undone from here.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={() => void setOutcome("no_show")}>Confirm no-show</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
