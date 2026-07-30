"use client";

import * as React from "react";
import { parseAsString, useQueryState } from "nuqs";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { ArrowRightLeft, ExternalLink } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { requestHandoffAction } from "@/app/(app)/projects/actions";
import { HANDOFF_MODE_OPTIONS, HANDOFF_STATUS_LABEL, HANDOFF_STATUS_VARIANT } from "@/lib/constants";
import type { ProjectHandoff, ProjectTeam, ProjectTeamMember } from "@/lib/projects/types";

const Schema = z.object({
  user_id: z.string().min(1, "Select a student."),
  mode: z.enum(["fork", "transfer"]),
  target_namespace_id: z.string().refine((v) => v !== "" && Number(v) > 0, "Enter the target GitLab namespace ID."),
  target_namespace_path: z.string().optional(),
});
type FormData = z.infer<typeof Schema>;

interface TeamHandoffDialogProps {
  team: ProjectTeam;
  assignmentId: string;
  members: ProjectTeamMember[];
}

// Staff-triggered capstone handoff: fork (new project, team's own repo
// untouched) or transfer (moves the team's project itself) into a target
// namespace, selectable per action (kind-herding-cookie.md §0.5). Default
// mode follows team size — fork for multi-member teams (a solo transfer
// would strand the rest of the team without their repo), transfer for solo
// teams — but the radio group always lets the caller override it.
export function TeamHandoffDialog({ team, assignmentId, members }: TeamHandoffDialogProps) {
  const [open, setOpen] = useQueryState("handoff-team", parseAsString);
  const isOpen = open === team.id;
  const [result, setResult] = React.useState<ProjectHandoff | null>(null);

  const defaultMode = members.length > 1 ? "fork" : "transfer";
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      user_id: members[0]?.user_id ?? "",
      mode: defaultMode,
      target_namespace_id: "",
      target_namespace_path: "",
    },
  });

  if (members.length === 0) return null;

  const onSubmit = async (data: FormData) => {
    const response = await requestHandoffAction(team.id, assignmentId, {
      user_id: data.user_id,
      mode: data.mode,
      target_namespace_id: Number(data.target_namespace_id),
      target_namespace_path: data.target_namespace_path?.trim() || undefined,
    });
    if (response.error) {
      toast.error(response.error);
      return;
    }
    toast.success("Handoff started — running in the background.");
    if (response.data) setResult(response.data);
  };

  function handleOpenChange(next: boolean) {
    void setOpen(next ? team.id : null);
    if (!next) {
      setResult(null);
      form.reset();
    }
  }

  const memberOptions = members.map((m) => ({ label: m.name || m.email || m.user_id, value: m.user_id }));

  return (
    <Dialog open={isOpen} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          <ArrowRightLeft aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          Hand off
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Hand off {team.name}&apos;s project</DialogTitle>
        </DialogHeader>

        {result ? (
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-2">
              <Badge variant={HANDOFF_STATUS_VARIANT[result.status] ?? "outline"}>
                {HANDOFF_STATUS_LABEL[result.status] ?? result.status}
              </Badge>
              <span className="text-sm text-muted-foreground capitalize">{result.mode}</span>
            </div>
            <p className="text-sm text-muted-foreground">
              You&apos;ll get a notification once the {result.mode} finishes — check the bell icon in the header.
            </p>
            {result.new_web_url ? (
              <a className="inline-flex items-center gap-1 text-sm text-primary hover:underline" href={result.new_web_url} rel="noreferrer" target="_blank">
                View project <ExternalLink aria-hidden className="h-3.5 w-3.5" />
              </a>
            ) : (
              result.target_namespace_path && <p className="text-sm text-muted-foreground">Target: {result.target_namespace_path}</p>
            )}
            <Button variant="outline" onClick={() => handleOpenChange(false)}>
              Close
            </Button>
          </div>
        ) : (
          <Form {...form}>
            <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
              <FormSelectField control={form.control} label="Student" name="user_id" options={memberOptions} />
              <FormField
                control={form.control}
                name="mode"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Mode</FormLabel>
                    <FormControl>
                      <RadioGroup className="grid-cols-1" value={field.value} onValueChange={field.onChange}>
                        {HANDOFF_MODE_OPTIONS.map((opt) => (
                          <label className="flex items-center gap-2 rounded-md border border-border p-3 text-sm" htmlFor={`handoff-mode-${opt.value}`} key={opt.value}>
                            <RadioGroupItem id={`handoff-mode-${opt.value}`} value={opt.value} />
                            {opt.label}
                          </label>
                        ))}
                      </RadioGroup>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormInputField
                control={form.control}
                description="The numeric ID of the GitLab group/user namespace to hand off into."
                label="Target namespace ID"
                name="target_namespace_id"
                type="number"
              />
              <FormInputField
                control={form.control}
                description="Optional — shown for reference only."
                label="Target namespace path (optional)"
                name="target_namespace_path"
              />
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Starting…" : "Start handoff"}
              </Button>
            </form>
          </Form>
        )}
      </DialogContent>
    </Dialog>
  );
}
