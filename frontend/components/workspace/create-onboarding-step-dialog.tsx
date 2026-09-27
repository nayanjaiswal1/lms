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
import { FormCheckboxField } from "@/components/ui/form-checkbox-field";
import { createOnboardingStepAction } from "@/lib/workspace/actions";

const Schema = z.object({
  title: z.string().min(1, "Title is required.").max(200),
  required: z.boolean(),
});
type FormData = z.infer<typeof Schema>;

interface CreateOnboardingStepDialogProps {
  workspaceId: string;
  nextPosition: number;
}

export function CreateOnboardingStepDialog({ workspaceId, nextPosition }: CreateOnboardingStepDialogProps) {
  const [open, setOpen] = useQueryState("new-step", parseAsBoolean.withDefault(false));
  const form = useForm<FormData>({ resolver: zodResolver(Schema), defaultValues: { title: "", required: true } });

  async function onSubmit(data: FormData) {
    const result = await createOnboardingStepAction(workspaceId, {
      title: data.title,
      required: data.required,
      position: nextPosition,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Step added.");
    void setOpen(null);
    form.reset();
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <PlusCircle aria-hidden className="h-4 w-4" />
          Add step
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Add onboarding step</DialogTitle>
          <DialogDescription>Shown to every member until they mark it done.</DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" placeholder="Set up local dev environment" />
            <FormCheckboxField control={form.control} label="Required to self-assign work" name="required" />
            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Adding…" : "Add step"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
