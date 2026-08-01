"use client";

import * as React from "react";
import { toast } from "sonner";
import { CalendarSync } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { rescheduleSessionAction, type Slot } from "@/lib/server/sessions";
import { SlotPicker } from "./slot-picker";

interface RescheduleSessionDialogProps {
  sessionId: string;
  /** Whose availability the new time is picked from — unchanged by a move. */
  mentorId: string;
  minNoticeHours: number;
}

/**
 * Moves a scheduled session to another open slot. The backend allows this for
 * the mentor or the student on the session, only while it is still scheduled,
 * and it carries the calendar event across to the new time.
 */
export function RescheduleSessionDialog({
  sessionId,
  mentorId,
  minNoticeHours,
}: RescheduleSessionDialogProps) {
  const [open, setOpen] = React.useState(false);
  const [state, setState] = React.useState<{ slot: Slot | null; saving: boolean }>({
    slot: null,
    saving: false,
  });

  async function handleConfirm() {
    if (!state.slot) return;
    setState((s) => ({ ...s, saving: true }));
    const result = await rescheduleSessionAction(sessionId, state.slot.starts_at, state.slot.ends_at);
    setState((s) => ({ ...s, saving: false }));
    if (!result.ok) {
      toast.error(result.error ?? "Could not move the session.");
      return;
    }
    toast.success("Session moved. Everyone's calendar is updated.");
    setState({ slot: null, saving: false });
    setOpen(false);
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="default" variant="outline">
          <CalendarSync aria-hidden className="mr-1.5 h-4 w-4" />
          Reschedule
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Move this session</DialogTitle>
          <DialogDescription>
            Pick a new open slot. The new time must be at least {minNoticeHours} hour
            {minNoticeHours === 1 ? "" : "s"} away.
          </DialogDescription>
        </DialogHeader>

        <SlotPicker mentorId={mentorId} onSelect={(slot) => setState((s) => ({ ...s, slot }))} />

        <DialogFooter>
          <Button disabled={!state.slot || state.saving} onClick={() => void handleConfirm()}>
            {state.saving ? "Moving…" : "Move session"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
