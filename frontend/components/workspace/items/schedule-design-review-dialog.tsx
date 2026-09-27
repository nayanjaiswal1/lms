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
import { scheduleDesignReviewAction } from "@/lib/workspace/phase3-actions";
import type { Member } from "@/lib/workspace/types";

// datetime-local <-> ISO — same convention as checkpoint-dialog.tsx.
function localInputToIso(value: string): string {
  return new Date(value).toISOString();
}

const Schema = z.object({
  title: z.string().min(3, "Give the review a title."),
  starts_at: z.string().min(1, "Pick a start time."),
});
type FormData = z.infer<typeof Schema>;

interface ScheduleDesignReviewDialogProps {
  workspaceId: string;
  itemId: string;
  itemTitle: string;
  members: Member[];
  /** Current doc reviewers — pre-checked as attendees (contract-phase3.md
   * "design review … with reviewers as attendees"), still adjustable. */
  reviewerIds: string[];
}

export function ScheduleDesignReviewDialog({ workspaceId, itemId, itemTitle, members, reviewerIds }: ScheduleDesignReviewDialogProps) {
  const [open, setOpen] = useState(false);
  const [attendeeIds, setAttendeeIds] = useState<string[]>(reviewerIds);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { title: `Design review: ${itemTitle}`, starts_at: "" },
  });

  function toggle(userId: string) {
    setAttendeeIds((prev) => (prev.includes(userId) ? prev.filter((id) => id !== userId) : [...prev, userId]));
  }

  async function onSubmit(data: FormData) {
    const result = await scheduleDesignReviewAction(workspaceId, itemId, {
      kind: "design_review",
      title: data.title,
      starts_at: localInputToIso(data.starts_at),
      attendee_ids: attendeeIds,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Design review scheduled.");
    setOpen(false);
  }

  const activeMembers = members.filter((m) => m.status === "active");

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="w-fit gap-2" size="sm" variant="outline">
          <CalendarPlus aria-hidden className="h-4 w-4" />
          Schedule design review
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader><DialogTitle>Schedule design review</DialogTitle></DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" />
            <FormInputField control={form.control} label="Starts at" name="starts_at" type="datetime-local" />
            <div className="flex flex-col gap-1.5">
              <span className="text-sm font-medium">Attendees</span>
              <ul className="flex max-h-40 flex-col gap-1.5 overflow-y-auto rounded-md border border-border p-2">
                {activeMembers.map((m) => (
                  <li className="flex items-center gap-2" key={m.user_id}>
                    <Checkbox
                      checked={attendeeIds.includes(m.user_id)}
                      id={`attendee-${m.user_id}`}
                      onCheckedChange={() => toggle(m.user_id)}
                    />
                    <label className="text-sm" htmlFor={`attendee-${m.user_id}`}>{m.name}</label>
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
