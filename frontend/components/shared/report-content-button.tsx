"use client";

import { useState } from "react";
import { toast } from "sonner";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Flag, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { Textarea } from "@/components/ui/textarea";
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { CONTENT_REPORT_REASON_OPTIONS } from "@/lib/constants";
import { reportContentAction } from "@/app/actions/report-content-action";

const reportSchema = z.object({
  reason: z.string().min(1, "Choose a reason"),
  description: z.string().max(2000, "Keep it under 2000 characters").optional(),
});
type ReportInput = z.infer<typeof reportSchema>;

interface ReportContentButtonProps {
  contentType: "wiki_page" | "course_module";
  contentId: string;
}

export function ReportContentButton({ contentType, contentId }: ReportContentButtonProps) {
  const [open, setOpen] = useState(false);
  const form = useForm<ReportInput>({
    resolver: zodResolver(reportSchema),
    defaultValues: { reason: "", description: "" },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    const result = await reportContentAction(contentType, contentId, values.reason, values.description ?? "");
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Thanks — our team will review this.");
    setOpen(false);
    form.reset();
  });

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button
        aria-label="Report this content"
        size="sm"
        type="button"
        variant="ghost"
        onClick={() => setOpen(true)}
      >
        <Flag aria-hidden className="h-4 w-4" />
        Report
      </Button>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Report this content</DialogTitle>
          <DialogDescription>
            Let us know if this is illegal, infringing, or otherwise violates our terms. Our
            moderation team reviews every report.
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={onSubmit}>
            <FormSelectField
              control={form.control}
              label="Reason"
              name="reason"
              options={CONTENT_REPORT_REASON_OPTIONS}
              placeholder="Select a reason"
            />
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Details (optional)</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Anything that helps our team review this" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? <Loader2 aria-hidden className="animate-spin" /> : null}
                Submit report
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
