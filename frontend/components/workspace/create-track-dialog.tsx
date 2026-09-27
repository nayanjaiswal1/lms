"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { parseAsBoolean, useQueryState } from "nuqs";
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
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { createTrackAction } from "@/lib/workspace/actions";

const Schema = z.object({
  name: z.string().min(1, "Name is required.").max(100),
});
type FormData = z.infer<typeof Schema>;

interface CreateTrackDialogProps {
  workspaceId: string;
}

export function CreateTrackDialog({ workspaceId }: CreateTrackDialogProps) {
  const [open, setOpen] = useQueryState("new-track", parseAsBoolean.withDefault(false));
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { name: "" } });

  async function onSubmit(data: FormData) {
    const result = await createTrackAction(workspaceId, { name: data.name });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Track created.");
    void setOpen(null);
    form.reset();
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <PlusCircle aria-hidden className="h-4 w-4" />
          New track
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>New track</DialogTitle>
          <DialogDescription>A name unique to this workspace — e.g. Frontend, Backend, QA.</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Track name" name="name" placeholder="Frontend" />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Creating…" : "Create track"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
