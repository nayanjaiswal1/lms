"use client";

import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
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
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { MENTOR_REPORT_REASON, MENTOR_REPORT_REASON_OPTIONS } from "@/lib/constants";
import { reportMentorAction } from "@/lib/mentoring/actions";

const ReportSchema = z.object({
  reason: z.enum([
    MENTOR_REPORT_REASON.UNRESPONSIVE,
    MENTOR_REPORT_REASON.INAPPROPRIATE_BEHAVIOR,
    MENTOR_REPORT_REASON.UNQUALIFIED,
    MENTOR_REPORT_REASON.OTHER,
  ]),
  description: z.string().min(10, "Please provide at least 10 characters.").max(2000),
});
type ReportFormData = z.infer<typeof ReportSchema>;

interface ReportMentorDialogProps {
  mentorId: string;
  ticketId?: string;
  showTrigger?: boolean;
}

export function ReportMentorDialog({ mentorId, ticketId, showTrigger = true }: ReportMentorDialogProps) {
  const [open, setOpen] = useQueryState("report", parseAsBoolean.withDefault(false));
  const form = useForm<ReportFormData>({
    resolver: zodResolver(ReportSchema),
    defaultValues: { reason: MENTOR_REPORT_REASON.UNRESPONSIVE, description: "" },
  });

  async function onSubmit(data: ReportFormData) {
    const result = await reportMentorAction(mentorId, data.reason, data.description, ticketId);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Report submitted. Our team will review it.");
    form.reset();
    void setOpen(null);
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      {showTrigger && (
        <DialogTrigger asChild>
          <Button variant="outline">Report this mentor</Button>
        </DialogTrigger>
      )}
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Report this mentor</DialogTitle>
          <DialogDescription>
            Let us know what happened. Our team reviews every report.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="reason"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Reason</FormLabel>
                  <FormControl>
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger aria-label="Reason">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {MENTOR_REPORT_REASON_OPTIONS.map((r) => (
                          <SelectItem key={r.value} value={r.value}>{r.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Describe what happened…" rows={4} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Submitting…" : "Submit report"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
