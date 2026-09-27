"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { FormSwitchField } from "@/components/ui/form-switch-field";
import { Input } from "@/components/ui/input";
import { TagInput } from "@/components/ui/tag-input";
import { updateWorkspaceAction } from "@/lib/workspace/actions";
import type { ProjectDetail } from "@/lib/workspace/types";

// datetime-local works in local time with no timezone suffix; the API
// exchanges UTC ISO strings — same conversion as create-project-form.tsx.
function isoToLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

const GeneralSchema = z
  .object({
    title: z.string().min(3, "Title must be at least 3 characters.").max(200),
    skills: z.array(z.string().max(40)).max(15, "Up to 15 skills."),
    team_size_min: z.string().refine((v) => Number(v) >= 2, "Minimum team size is 2."),
    team_size_max: z.string().refine((v) => Number(v) <= 50, "Maximum team size is 50."),
    interest_deadline: z.string(),
    key_prefix: z.string().regex(/^[A-Z]{2,6}$/, "2–6 uppercase letters, e.g. PAY."),
    accepting_interests: z.boolean(),
    gitlab_enabled: z.boolean(),
    sprints_enabled: z.boolean(),
  })
  .refine((v) => Number(v.team_size_max) >= Number(v.team_size_min), {
    message: "Max team size must be at least the min team size.",
    path: ["team_size_max"],
  });
type GeneralFormData = z.infer<typeof GeneralSchema>;

interface GeneralSettingsFormProps {
  workspaceId: string;
  project: ProjectDetail;
}

export function GeneralSettingsForm({ workspaceId, project }: GeneralSettingsFormProps) {
  const keyPrefixLocked = project.item_seq > 0;
  const form = useForm<GeneralFormData>({
    resolver: zodResolver(GeneralSchema),
    defaultValues: {
      title: project.title,
      skills: project.skills,
      team_size_min: String(project.team_size_min),
      team_size_max: String(project.team_size_max),
      interest_deadline: isoToLocalInput(project.interest_deadline),
      key_prefix: project.key_prefix,
      accepting_interests: project.accepting_interests,
      gitlab_enabled: project.gitlab_enabled,
      sprints_enabled: project.sprints_enabled,
    },
  });

  async function onSubmit(data: GeneralFormData) {
    const result = await updateWorkspaceAction(workspaceId, {
      title: data.title,
      skills: data.skills,
      team_size_min: Number(data.team_size_min),
      team_size_max: Number(data.team_size_max),
      interest_deadline: data.interest_deadline ? new Date(data.interest_deadline).toISOString() : null,
      clear_interest_deadline: !data.interest_deadline,
      key_prefix: keyPrefixLocked ? undefined : data.key_prefix,
      accepting_interests: data.accepting_interests,
      gitlab_enabled: data.gitlab_enabled,
      sprints_enabled: data.sprints_enabled,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Settings saved.");
  }

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormInputField control={form.control} label="Title" name="title" />

        <FormField
          control={form.control}
          name="skills"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Skills</FormLabel>
              <FormControl>
                <TagInput placeholder="Add a skill and press Enter…" value={field.value} onChange={field.onChange} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="grid gap-4 sm:grid-cols-2">
          <FormInputField control={form.control} label="Min team size" name="team_size_min" type="number" />
          <FormInputField control={form.control} label="Max team size" name="team_size_max" type="number" />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <FormField
            control={form.control}
            name="interest_deadline"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Interest deadline</FormLabel>
                <FormControl>
                  <Input type="datetime-local" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
          <FormInputField
            control={form.control}
            description={keyPrefixLocked ? "Locked once the first ticket is created." : "2–6 uppercase letters."}
            disabled={keyPrefixLocked}
            label="Ticket key prefix"
            name="key_prefix"
          />
        </div>

        <FormSwitchField
          control={form.control}
          description="Turn off to stop the public share page from accepting new interest."
          label="Accepting interests"
          name="accepting_interests"
        />
        <FormSwitchField
          control={form.control}
          description="Requires a linked GitLab team before the workspace can go active."
          label="GitLab integration"
          name="gitlab_enabled"
        />
        <FormSwitchField control={form.control} description="Enables sprint planning once active." label="Sprints" name="sprints_enabled" />

        <Button className="self-end px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Saving…" : "Save changes"}
        </Button>
      </form>
    </Form>
  );
}
