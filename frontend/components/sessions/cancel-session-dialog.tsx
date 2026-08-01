"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
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
import { Textarea } from "@/components/ui/textarea";
import { cancelSessionAction } from "@/lib/server/sessions";

const CancelSchema = z.object({
  reason: z.string().max(500, "Keep it under 500 characters.").optional(),
});
type CancelFormData = z.infer<typeof CancelSchema>;

interface CancelSessionDialogProps {
  sessionId: string;
  cancelCutoffHours: number;
  startsAt: string;
}

export function CancelSessionDialog({ sessionId, cancelCutoffHours, startsAt }: CancelSessionDialogProps) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  const form = useForm<CancelFormData>({
    resolver: zodResolver(CancelSchema),
    defaultValues: { reason: "" },
  });

  const hoursUntilStart = (new Date(startsAt).getTime() - Date.now()) / (1000 * 60 * 60);
  const withinCutoff = hoursUntilStart < cancelCutoffHours;

  async function onSubmit(data: CancelFormData) {
    const result = await cancelSessionAction(sessionId, data.reason ?? "");
    if (result.error) {
      toast.error(result.error);
      return;
    }
    const cancellation = result.data;
    if (cancellation?.credit_refunded) {
      toast.success("Session cancelled. Your credit was returned.");
    } else if (cancellation?.within_cutoff && !cancellation.credit_refunded) {
      toast.success(
        `Session cancelled inside the ${cancellation.cutoff_hours}-hour window — the credit was not returned.`,
      );
    } else {
      toast.success("Session cancelled.");
    }
    form.reset();
    setOpen(false);
    router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline">Cancel session</Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Cancel this session?</DialogTitle>
          <DialogDescription>
            {withinCutoff
              ? `You're inside the ${cancelCutoffHours}-hour cancellation window — cancelling now will not return a credit.`
              : "You can add an optional note for the other party."}
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="reason"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Reason (optional)</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Let them know why…" rows={3} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button
                disabled={form.formState.isSubmitting}
                type="button"
                variant="ghost"
                onClick={() => setOpen(false)}
              >
                Keep session
              </Button>
              <Button disabled={form.formState.isSubmitting} type="submit" variant="destructive">
                {form.formState.isSubmitting ? "Cancelling…" : "Cancel session"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
