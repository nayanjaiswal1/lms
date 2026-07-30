"use client";

import { Plus, Pencil } from "lucide-react";
import { parseAsString, useQueryState } from "nuqs";
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
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { createCheckpointAction, updateCheckpointAction } from "@/app/(app)/projects/actions";
import { cn } from "@/lib/utils";
import type { ProjectCheckpoint } from "@/lib/projects/types";

// datetime-local <-> ISO conversion — matches edit-assignment-panel.tsx's
// own localInputToIso/isoToLocalInput convention exactly.
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

const Schema = z.object({
  title: z.string().min(2, "Title is too short."),
  description: z.string().optional(),
  position: z.string().refine((v) => v !== "" && Number(v) >= 1, "Enter a position of 1 or more."),
  weight: z.string().refine((v) => v !== "" && Number(v) >= 0, "Enter a number."),
  due_at: z.string().optional(),
  requires_mr: z.boolean(),
  requires_ci_pass: z.boolean(),
});
type FormData = z.infer<typeof Schema>;

interface CheckpointDialogProps {
  assignmentId: string;
  /** Editing an existing checkpoint — omit to render the "create" form. */
  checkpoint?: ProjectCheckpoint;
  /** Next free position — only used for the create form's default. */
  nextPosition?: number;
}

// One dialog handles both create and edit — the field set is identical
// either way (only defaultValues and the action called on submit differ), so
// a single component avoids duplicating the ~10-field form twice.
export function CheckpointDialog({ assignmentId, checkpoint, nextPosition = 1 }: CheckpointDialogProps) {
  const isEdit = Boolean(checkpoint);
  const [open, setOpen] = useQueryState(isEdit ? "edit-checkpoint" : "create-checkpoint", parseAsString);
  const isOpen = checkpoint ? open === checkpoint.id : open === "1";

  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      title: checkpoint?.title ?? "",
      description: checkpoint?.description ?? "",
      position: String(checkpoint?.position ?? nextPosition),
      weight: String(checkpoint?.weight ?? 100),
      due_at: isoToLocalInput(checkpoint?.due_at ?? null),
      requires_mr: checkpoint?.requires_mr ?? true,
      requires_ci_pass: checkpoint?.requires_ci_pass ?? true,
    },
  });

  const onSubmit = async (data: FormData) => {
    const fields = {
      title: data.title,
      description: data.description?.trim() ? data.description.trim() : null,
      weight: Number(data.weight),
      due_at: localInputToIso(data.due_at ?? ""),
      requires_mr: data.requires_mr,
      requires_ci_pass: data.requires_ci_pass,
    };
    // Position has no place in CheckpointPatch (backend/internal/gitlab/
    // models.go — confirmed by reading it directly, not assumed): it's only
    // ever set at creation time, so the field below is create-only and never
    // sent on an update.
    const result = checkpoint
      ? await updateCheckpointAction(checkpoint.id, assignmentId, fields)
      : await createCheckpointAction(assignmentId, { ...fields, position: Number(data.position) });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(isEdit ? "Checkpoint updated." : "Checkpoint created.");
    if (!isEdit) form.reset();
    void setOpen(null);
  };

  return (
    <Dialog open={isOpen} onOpenChange={(next) => void setOpen(next ? (checkpoint ? checkpoint.id : "1") : null)}>
      <DialogTrigger asChild>
        {checkpoint ? (
          <Button aria-label={`Edit ${checkpoint.title}`} size="icon" variant="ghost">
            <Pencil aria-hidden className="h-4 w-4" />
          </Button>
        ) : (
          <Button size="sm">
            <Plus aria-hidden className="mr-1.5 h-4 w-4" />
            Add checkpoint
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="modal-responsive max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit checkpoint" : "Add checkpoint"}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" placeholder="Checkpoint 1: API skeleton" />
            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Description</FormLabel>
                  <FormControl>
                    <Textarea placeholder="Optional summary shown to teams…" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <div className={cn("grid gap-4", !checkpoint && "sm:grid-cols-2")}>
              {/* Position is create-only — see onSubmit's own comment on why
                  it's never part of the update payload. */}
              {!checkpoint && <FormInputField control={form.control} label="Position" name="position" type="number" />}
              <FormInputField control={form.control} label="Weight" name="weight" type="number" />
            </div>
            <FormField
              control={form.control}
              name="due_at"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Due (optional)</FormLabel>
                  <FormControl>
                    <Input type="datetime-local" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="requires_mr"
              render={({ field }) => (
                <FormItem className="flex items-center gap-3 space-y-0">
                  <FormControl>
                    <Checkbox checked={field.value} onCheckedChange={field.onChange} />
                  </FormControl>
                  <FormLabel className="font-normal">Requires a merge request as submission</FormLabel>
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="requires_ci_pass"
              render={({ field }) => (
                <FormItem className="flex items-center gap-3 space-y-0">
                  <FormControl>
                    <Checkbox checked={field.value} onCheckedChange={field.onChange} />
                  </FormControl>
                  <FormLabel className="font-normal">Requires CI to pass before merging</FormLabel>
                </FormItem>
              )}
            />
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Saving…" : isEdit ? "Save changes" : "Create checkpoint"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
