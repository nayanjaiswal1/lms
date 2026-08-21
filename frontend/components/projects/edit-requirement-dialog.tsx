"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Pencil } from "lucide-react";
import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { updateRequirementAction } from "@/app/(app)/projects/actions";
import type { ProjectRequirement } from "@/lib/projects/types";

// datetime-local <-> ISO conversion — matches checkpoint-dialog.tsx's own
// isoToLocalInput/localInputToIso convention exactly.
function isoToLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

const Schema = z
  .object({
    title: z.string().min(2, "Title is too short."),
    brief: z.string().min(10, "Give students enough detail to decide whether to apply."),
    required_skills: z.string(),
    team_size_min: z.string().refine((v) => Number(v) >= 1, "Enter at least 1."),
    team_size_max: z.string().refine((v) => Number(v) >= 1, "Enter at least 1."),
    application_deadline: z.string().min(1, "An application deadline is required."),
  })
  .refine((v) => Number(v.team_size_max) >= Number(v.team_size_min), {
    message: "Max team size must be at least the min team size.",
    path: ["team_size_max"],
  });
type FormData = z.infer<typeof Schema>;

interface EditRequirementDialogProps {
  requirement: ProjectRequirement;
}

export function EditRequirementDialog({ requirement }: EditRequirementDialogProps) {
  const [open, setOpen] = useQueryState("edit-requirement", parseAsBoolean.withDefault(false));
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      title: requirement.title,
      brief: requirement.brief,
      required_skills: requirement.required_skills.join(", "),
      team_size_min: String(requirement.team_size_min),
      team_size_max: String(requirement.team_size_max),
      application_deadline: isoToLocalInput(requirement.application_deadline),
    },
  });

  const onSubmit = async (data: FormData) => {
    const result = await updateRequirementAction(requirement.id, {
      title: data.title,
      brief: data.brief,
      required_skills: data.required_skills
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
      team_size_min: Number(data.team_size_min),
      team_size_max: Number(data.team_size_max),
      application_deadline: new Date(data.application_deadline).toISOString(),
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Requirement updated.");
    void setOpen(false);
    router.refresh();
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          <Pencil aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          Edit
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit requirement</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" />
            <FormField
              control={form.control}
              name="brief"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Brief</FormLabel>
                  <FormControl>
                    <Textarea rows={6} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormInputField
              control={form.control}
              description="Comma-separated."
              label="Required skills"
              name="required_skills"
            />
            <div className="grid gap-4 sm:grid-cols-2">
              <FormInputField control={form.control} label="Min team size" name="team_size_min" type="number" />
              <FormInputField control={form.control} label="Max team size" name="team_size_max" type="number" />
            </div>
            <FormField
              control={form.control}
              name="application_deadline"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Application deadline</FormLabel>
                  <FormControl>
                    <Input type="datetime-local" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Save changes"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
