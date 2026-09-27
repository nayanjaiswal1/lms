"use client";

import { useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { recordAttendanceAction } from "@/lib/workspace/phase3-actions";
import type { Meeting, Member } from "@/lib/workspace/types";

function isoToLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

interface AttendanceDialogProps {
  workspaceId: string;
  meeting: Meeting;
  members: Member[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** Manager+ attendance sheet. Meeting occurrences (recurring meetings) aren't
 * enumerated anywhere in the API, so `occurrence_at` starts at the meeting's
 * `starts_at` but stays editable — the manager picks the occurrence being
 * recorded (contract-phase3.md's upsert-per-occurrence rule). */
export function AttendanceDialog({ workspaceId, meeting, members, open, onOpenChange }: AttendanceDialogProps) {
  const activeMembers = members.filter((m) => m.status === "active");
  const [occurrenceAt, setOccurrenceAt] = useState(() => isoToLocalInput(meeting.starts_at));
  const [attended, setAttended] = useState<Set<string>>(new Set());
  const [pending, setPending] = useState(false);

  function toggle(userId: string) {
    setAttended((prev) => {
      const next = new Set(prev);
      if (next.has(userId)) next.delete(userId);
      else next.add(userId);
      return next;
    });
  }

  async function submit() {
    if (!occurrenceAt) {
      toast.error("Pick the occurrence date/time.");
      return;
    }
    setPending(true);
    const result = await recordAttendanceAction(workspaceId, meeting.calendar_event_id, {
      occurrence_at: new Date(occurrenceAt).toISOString(),
      attendance: activeMembers.map((m) => ({ user_id: m.user_id, attended: attended.has(m.user_id) })),
    });
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Attendance recorded.");
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="modal-responsive">
        <DialogHeader><DialogTitle>Record attendance — {meeting.title}</DialogTitle></DialogHeader>
        <div className="form-stack">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium" htmlFor="occurrence-at">Occurrence</label>
            <Input
              id="occurrence-at"
              type="datetime-local"
              value={occurrenceAt}
              onChange={(e) => setOccurrenceAt(e.target.value)}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <span className="text-sm font-medium">Attendees</span>
            <ul className="flex max-h-56 flex-col gap-1.5 overflow-y-auto rounded-md border border-border p-2">
              {activeMembers.map((m) => (
                <li className="flex items-center gap-2" key={m.user_id}>
                  <Checkbox checked={attended.has(m.user_id)} id={`attended-${m.user_id}`} onCheckedChange={() => toggle(m.user_id)} />
                  <label className="text-sm" htmlFor={`attended-${m.user_id}`}>{m.name}</label>
                </li>
              ))}
            </ul>
          </div>
        </div>
        <DialogFooter>
          <Button disabled={pending} onClick={submit}>{pending ? "Saving…" : "Save attendance"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
