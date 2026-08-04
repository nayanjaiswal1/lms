"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { parseAsBoolean, useQueryState } from "nuqs";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { PlusCircle } from "lucide-react";
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
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { createSupportTicketAction } from "@/lib/support/actions";

const CreateTicketSchema = z.object({
  subject: z.string().min(3, "Subject must be at least 3 characters.").max(200),
  message: z.string().min(1, "Tell us what's going on.").max(4000),
});
type CreateTicketFormData = z.infer<typeof CreateTicketSchema>;

// Category and priority are deliberately not asked here — a staff member
// triages those after reading the ticket (see TicketPropertiesSelect), not
// the reporter guessing from a dropdown before anyone's looked at it.
export function CreateTicketDialog() {
  const [open, setOpen] = useQueryState("new-ticket", parseAsBoolean.withDefault(false));
  const [, setTicket] = useQueryState("ticket");
  const router = useRouter();
  const form = useForm<CreateTicketFormData>({
    resolver: zodResolver(CreateTicketSchema),
    defaultValues: { subject: "", message: "" },
  });

  async function onSubmit(data: CreateTicketFormData) {
    const result = await createSupportTicketAction(data.subject, data.message);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Ticket submitted.");
    void setOpen(null);
    form.reset();
    if (result.data) void setTicket(result.data.id);
    else router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <PlusCircle aria-hidden className="h-4 w-4" />
          New ticket
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Raise a support ticket</DialogTitle>
          <DialogDescription>
            Tell us what&apos;s going on and a team member will follow up here.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="subject"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Subject</FormLabel>
                  <FormControl>
                    <Input placeholder="Short summary of the issue" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="message"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Message</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Describe what's happening, and any steps to reproduce it…" rows={5} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Submitting…" : "Submit ticket"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
