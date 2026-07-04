"use client";

import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
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
import { requestMentorChangeAction } from "@/lib/mentoring/actions";

const RequestChangeSchema = z.object({
  reason: z.string().min(10, "Please provide at least 10 characters.").max(1000),
});
type RequestChangeFormData = z.infer<typeof RequestChangeSchema>;

interface RequestMentorChangeDialogProps {
  ticketId: string;
}

export function RequestMentorChangeDialog({ ticketId }: RequestMentorChangeDialogProps) {
  const [open, setOpen] = useQueryState("request-change", parseAsBoolean.withDefault(false));
  const router = useRouter();
  const form = useForm<RequestChangeFormData>({
    resolver: zodResolver(RequestChangeSchema),
    defaultValues: { reason: "" },
  });

  async function onSubmit(data: RequestChangeFormData) {
    const result = await requestMentorChangeAction(ticketId, data.reason);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Request submitted. Our team will review it.");
    form.reset();
    void setOpen(null);
    router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button variant="outline">Request a different mentor</Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Request a different mentor</DialogTitle>
          <DialogDescription>
            Tell us why you&apos;d like a change. Staff will review your request before reassigning you.
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
                    <Textarea placeholder="Why would you like a different mentor?" rows={4} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Submitting…" : "Submit request"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
