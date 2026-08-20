"use client";

import { UserCheck } from "lucide-react";
import { parseAsBoolean, useQueryState } from "nuqs";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { createTeamFromSelectionAction } from "@/app/(app)/projects/actions";
import type { ProjectAssignment } from "@/lib/projects/types";
import ROUTES from "@/lib/routes";

const Schema = z.object({
  assignment_id: z.string().min(1, "Choose an assignment."),
  team_name: z.string().min(2, "Name is too short."),
  team_slug: z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Use lowercase letters, numbers, and hyphens only."),
});
type FormData = z.infer<typeof Schema>;

interface CreateTeamFromSelectionDialogProps {
  requirementId: string;
  selectedCount: number;
  assignments: ProjectAssignment[];
}

export function CreateTeamFromSelectionDialog({ requirementId, selectedCount, assignments }: CreateTeamFromSelectionDialogProps) {
  const [open, setOpen] = useQueryState("create-team", parseAsBoolean.withDefault(false));
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { assignment_id: "", team_name: "", team_slug: "" },
  });

  if (selectedCount === 0) return null;

  const onSubmit = async (data: FormData) => {
    const res = await createTeamFromSelectionAction(requirementId, data);
    if (res.error || !res.data) {
      toast.error(res.error ?? "Could not create the team.");
      return;
    }
    toast.success(`Team created with ${res.data.added_user_ids.length} of ${selectedCount} selected applicant(s).`);
    form.reset();
    void setOpen(false);
    router.push(ROUTES.projectAssignment(data.assignment_id));
  };

  const assignmentOptions = assignments
    .filter((a) => a.status !== "archived")
    .map((a) => ({ label: a.title, value: a.id }));

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <UserCheck aria-hidden className="mr-1.5 h-4 w-4" />
          Create team from {selectedCount} selected
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Create team from selection</DialogTitle>
        </DialogHeader>
        {assignmentOptions.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            No assignment to attach this team to yet.{" "}
            <a className="underline" href={ROUTES.PROJECTS_NEW}>
              Create one first
            </a>
            , then come back here.
          </p>
        ) : (
          <Form {...form}>
            <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
              <p className="text-sm text-muted-foreground">
                All {selectedCount} applicant{selectedCount === 1 ? "" : "s"} marked &ldquo;selected&rdquo; will be added
                as members.
              </p>
              <FormSelectField
                control={form.control}
                label="Assignment"
                name="assignment_id"
                options={assignmentOptions}
                placeholder="Choose an assignment"
              />
              <FormInputField control={form.control} label="Team name" name="team_name" placeholder="Team Byte Bandits" />
              <FormInputField control={form.control} label="Slug" name="team_slug" placeholder="team-byte-bandits" />
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Creating…" : "Create team"}
              </Button>
            </form>
          </Form>
        )}
      </DialogContent>
    </Dialog>
  );
}
