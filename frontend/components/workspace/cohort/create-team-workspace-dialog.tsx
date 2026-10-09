"use client";

import { Plus } from "lucide-react";
import { parseAsBoolean, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { createCohortWorkspaceAction } from "@/lib/workspace/cohort-actions";
import type { BatchMember } from "@/lib/server/batches";

const Schema = z.object({
  title: z.string().min(2, "Title is too short."),
  member_user_ids: z.array(z.string()).min(1, "Pick at least one member."),
});
type FormData = z.infer<typeof Schema>;

interface CreateTeamWorkspaceDialogProps {
  cohortId: string;
  availableStudents: BatchMember[];
}

export function CreateTeamWorkspaceDialog({ cohortId, availableStudents }: CreateTeamWorkspaceDialogProps) {
  const [open, setOpen] = useQueryState("create-team", parseAsBoolean.withDefault(false));
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { title: "", member_user_ids: [] },
  });
  const selected = form.watch("member_user_ids");

  const toggle = (userId: string, checked: boolean) =>
    form.setValue("member_user_ids", checked ? [...selected, userId] : selected.filter((id) => id !== userId), {
      shouldValidate: form.formState.isSubmitted,
    });

  const onSubmit = async (data: FormData) => {
    const res = await createCohortWorkspaceAction(cohortId, data);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Team workspace created.");
    form.reset();
    void setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <Plus aria-hidden className="mr-1.5 h-4 w-4" />
          Create team workspace
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Create team workspace</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormInputField control={form.control} label="Title" name="title" placeholder="Team Byte Bandits" />
            <div className="flex flex-col gap-2">
              <span className="text-sm font-medium">Members ({selected.length} selected)</span>
              {availableStudents.length === 0 ? (
                <p className="text-sm text-muted-foreground">Every batch member is already on a team.</p>
              ) : (
                <ScrollArea className="h-56 rounded-md border">
                  <ul className="flex flex-col gap-1 p-2">
                    {availableStudents.map((s) => (
                      <li key={s.user_id}>
                        <label className="flex min-w-0 cursor-pointer items-center gap-3 rounded-md p-2 hover:bg-muted">
                          <Checkbox checked={selected.includes(s.user_id)} onCheckedChange={(c) => toggle(s.user_id, c === true)} />
                          <span className="min-w-0 truncate text-sm">
                            {s.name} <span className="text-muted-foreground">({s.email})</span>
                          </span>
                        </label>
                      </li>
                    ))}
                  </ul>
                </ScrollArea>
              )}
              {form.formState.errors.member_user_ids && (
                <p className="text-sm text-destructive">{form.formState.errors.member_user_ids.message}</p>
              )}
            </div>
            <Button disabled={form.formState.isSubmitting} type="submit">
              {form.formState.isSubmitting ? "Creating…" : "Create team workspace"}
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
