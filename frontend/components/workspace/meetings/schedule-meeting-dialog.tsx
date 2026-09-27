"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { CalendarPlus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { scheduleMeetingAction } from "@/lib/workspace/phase3-actions";
import { MEETING_KIND_LABEL } from "@/lib/workspace/meetings-constants";
import type { Member, MeetingKind } from "@/lib/workspace/types";

// datetime-local <-> ISO — same convention as checkpoint-dialog.tsx.
function localInputToIso(value: string): string | null {
  return value ? new Date(value).toISOString() : null;
}

const KIND_OPTIONS: { label: string; value: MeetingKind }[] = (
  ["kickoff", "sprint_planning", "standup", "design_review", "retro", "demo"] as const
).map((k) => ({ label: MEETING_KIND_LABEL[k], value: k }));

const Schema = z.object({
  kind: z.enum(["kickoff", "sprint_planning", "standup", "design_review", "retro", "demo"]),
  title: z.string().min(3, "Give the meeting a title."),
  starts_at: z.string().min(1, "Pick a start time."),
  ends_at: z.string().optional(),
  meeting_url: z.string().url("Enter a valid URL.").optional().or(z.literal("")),
});
type FormData = z.infer<typeof Schema>;

interface ScheduleMeetingDialogProps {
  workspaceId: string;
  members: Member[];
}

export function ScheduleMeetingDialog({ workspaceId, members }: ScheduleMeetingDialogProps) {
  const [open, setOpen] = useState(false);
  const [attendeeIds, setAttendeeIds] = useState<string[]>([]);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { kind: "sprint_planning", title: "", starts_at: "", ends_at: "", meeting_url: "" },
  });
  const activeMembers = members.filter((m) => m.status === "active");

  function toggle(userId: string) {
    setAttendeeIds((prev) => (prev.includes(userId) ? prev.filter((id) => id !== userId) : [...prev, userId]));
  }

  async function onSubmit(data: FormData) {
    const result = await scheduleMeetingAction(workspaceId, {
      kind: data.kind,
      title: data.title,
      starts_at: localInputToIso(data.starts_at) as string,
      ends_at: localInputToIso(data.ends_at ?? ""),
      meeting_url: data.meeting_url || null,
      attendee_ids: attendeeIds,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Meeting scheduled.");
    setOpen(false);
    form.reset({ kind: "sprint_planning", title: "", starts_at: "", ends_at: "", meeting_url: "" });
    setAttendeeIds([]);
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <CalendarPlus aria-hidden className="h-4 w-4" />
          Schedule meeting
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader><DialogTitle>Schedule meeting</DialogTitle></DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormSelectField control={form.control} label="Kind" name="kind" options={KIND_OPTIONS} />
            <FormInputField control={form.control} label="Title" name="title" />
            <FormInputField control={form.control} label="Starts at" name="starts_at" type="datetime-local" />
            <FormInputField control={form.control} label="Ends at (optional)" name="ends_at" type="datetime-local" />
            <FormInputField control={form.control} label="Meeting URL (optional)" name="meeting_url" />
            <div className="flex flex-col gap-1.5">
              <span className="text-sm font-medium">Attendees</span>
              <ul className="flex max-h-40 flex-col gap-1.5 overflow-y-auto rounded-md border border-border p-2">
                {activeMembers.map((m) => (
                  <li className="flex items-center gap-2" key={m.user_id}>
                    <Checkbox
                      checked={attendeeIds.includes(m.user_id)}
                      id={`schedule-attendee-${m.user_id}`}
                      onCheckedChange={() => toggle(m.user_id)}
                    />
                    <label className="text-sm" htmlFor={`schedule-attendee-${m.user_id}`}>{m.name}</label>
                  </li>
                ))}
              </ul>
            </div>
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Scheduling…" : "Schedule"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
