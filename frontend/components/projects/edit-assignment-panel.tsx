"use client";

import { Pencil } from "lucide-react";
import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { updateAssignmentAction } from "@/app/(app)/projects/actions";
import { PROJECT_VISIBILITY_OPTIONS } from "@/lib/constants";
import type { ProjectAssignment } from "@/lib/projects/types";

function isoToLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function localInputToIso(value: string): string | null {
  if (!value) return null;
  return new Date(value).toISOString();
}

const Schema = z
  .object({
    title: z.string().min(2, "Title is too short."),
    description: z.string().optional(),
    visibility: z.enum(["private", "internal"]),
    required_approvals: z.string().refine((v) => v !== "" && Number(v) >= 0, "Enter a number."),
    protect_default_branch: z.boolean(),
    default_branch: z.string().min(1, "Default branch is required."),
    starts_at: z.string().optional(),
    due_at: z.string().optional(),
  })
  .refine((v) => !v.starts_at || !v.due_at || v.due_at > v.starts_at, {
    message: "Due date must be after the start date.",
    path: ["due_at"],
  });
type FormData = z.infer<typeof Schema>;

interface EditAssignmentPanelProps {
  assignment: ProjectAssignment;
}

export function EditAssignmentPanel({ assignment }: EditAssignmentPanelProps) {
  const [open, setOpen] = useQueryState("edit-assignment", parseAsBoolean.withDefault(false));
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      title: assignment.title,
      description: assignment.description ?? "",
      visibility: assignment.visibility,
      required_approvals: String(assignment.required_approvals),
      protect_default_branch: assignment.protect_default_branch,
      default_branch: assignment.default_branch,
      starts_at: isoToLocalInput(assignment.starts_at),
      due_at: isoToLocalInput(assignment.due_at),
    },
  });

  const onSubmit = async (data: FormData) => {
    const result = await updateAssignmentAction(assignment.id, {
      title: data.title,
      description: data.description?.trim() ? data.description.trim() : null,
      visibility: data.visibility,
      required_approvals: Number(data.required_approvals),
      protect_default_branch: data.protect_default_branch,
      default_branch: data.default_branch,
      starts_at: localInputToIso(data.starts_at ?? ""),
      due_at: localInputToIso(data.due_at ?? ""),
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Assignment updated.");
    void setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline">
          <Pencil aria-hidden className="mr-1.5 h-4 w-4" />
          Edit
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit assignment</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" />
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Optional…" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormSelectField control={form.control} label="Visibility" name="visibility" options={PROJECT_VISIBILITY_OPTIONS} />
            <div className="grid gap-4 sm:grid-cols-2">
              <FormInputField control={form.control} label="Required approvals" name="required_approvals" type="number" />
              <FormInputField control={form.control} label="Default branch" name="default_branch" />
            </div>
            <FormField
              control={form.control}
              name="protect_default_branch"
              render={({ field }) => (
                <FormItem className="flex items-center gap-3 space-y-0">
                  <FormControl>
                    <Checkbox checked={field.value} onCheckedChange={field.onChange} />
                  </FormControl>
                  <FormLabel className="font-normal">Protect the default branch</FormLabel>
                </FormItem>
              )}
            />
            <div className="grid gap-4 sm:grid-cols-2">
              <FormField
                control={form.control}
                name="starts_at"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Starts</FormLabel>
                    <FormControl>
                      <Input type="datetime-local" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="due_at"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Due</FormLabel>
                    <FormControl>
                      <Input type="datetime-local" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : "Save changes"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
