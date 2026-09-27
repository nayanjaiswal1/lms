"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { Award } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { issueCertificateAction } from "@/lib/workspace/phase5-actions";

const Schema = z.object({
  experience_note: z.string().max(2000),
});
type FormData = z.infer<typeof Schema>;

interface IssueCertificateDialogProps {
  workspaceId: string;
  userId: string;
  userName: string;
  hasCertificate: boolean;
}

/** Owner-only, project completed (contract-phase5.md 5b) — a deliberate
 * human award, never automatic. */
export function IssueCertificateDialog({ workspaceId, userId, userName, hasCertificate }: IssueCertificateDialogProps) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { experience_note: "" } });

  async function onSubmit(data: FormData) {
    const result = await issueCertificateAction(workspaceId, { user_id: userId, experience_note: data.experience_note });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Certificate issued to ${userName}.`);
    setOpen(false);
    router.refresh();
  }

  if (hasCertificate) return null;

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2" size="sm">
          <Award aria-hidden className="h-4 w-4" />
          Issue certificate
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader><DialogTitle>Issue a certificate to {userName}</DialogTitle></DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormField
              control={form.control}
              name="experience_note"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Experience note (optional)</FormLabel>
                  <FormControl>
                    <Textarea {...field} placeholder="What did they contribute?" rows={4} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Issuing…" : "Issue certificate"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
