"use client";

import { useRouter } from "next/navigation";
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
import { createAssignmentAction } from "@/app/(app)/projects/actions";
import { PROJECT_VISIBILITY_OPTIONS } from "@/lib/constants";
import type { Batch } from "@/lib/server/batches";
import type { GitlabInstallationStatus } from "@/components/settings/gitlab-installation-card";
import ROUTES from "@/lib/routes";

// Sentinel for "follow the org's default connection" — Radix Select's
// SelectItem rejects an empty-string value, so this is translated back to
// `undefined` (omit installation_id entirely) at submit time.
const DEFAULT_INSTALLATION_VALUE = "__default__";

// datetime-local inputs work in local time with no timezone suffix; the API
// exchanges UTC ISO strings, so convert at the edges (matches
// app/(app)/batches/[id]/edit-batch-panel.tsx's convention).
function localInputToIso(value: string): string | null {
  if (!value) return null;
  return new Date(value).toISOString();
}

const Schema = z
  .object({
    batch_id: z.string().min(1, "Choose a batch."),
    title: z.string().min(2, "Title is too short."),
    slug: z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Use lowercase letters, numbers, and hyphens only."),
    description: z.string().optional(),
    template_project_path: z.string().min(1, "The template repo path is required."),
    installation_id: z.string(),
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

interface CreateAssignmentFormProps {
  batches: Batch[];
  installations: GitlabInstallationStatus[];
  allowInstallationOverride: boolean;
}

export function CreateAssignmentForm({ batches, installations, allowInstallationOverride }: CreateAssignmentFormProps) {
  const router = useRouter();
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: {
      batch_id: "",
      title: "",
      slug: "",
      description: "",
      template_project_path: "",
      installation_id: DEFAULT_INSTALLATION_VALUE,
      visibility: "private",
      required_approvals: "1",
      protect_default_branch: true,
      default_branch: "main",
      starts_at: "",
      due_at: "",
    },
  });

  const onSubmit = async (data: FormData) => {
    const res = await createAssignmentAction({
      batch_id: data.batch_id,
      title: data.title,
      slug: data.slug,
      description: data.description?.trim() ? data.description.trim() : undefined,
      template_project_path: data.template_project_path,
      installation_id: data.installation_id === DEFAULT_INSTALLATION_VALUE ? undefined : data.installation_id,
      visibility: data.visibility,
      required_approvals: Number(data.required_approvals),
      protect_default_branch: data.protect_default_branch,
      default_branch: data.default_branch,
      starts_at: localInputToIso(data.starts_at ?? ""),
      due_at: localInputToIso(data.due_at ?? ""),
    });
    if (res.error || !res.data) {
      toast.error(res.error ?? "Could not create the assignment.");
      return;
    }
    toast.success("Assignment created as a draft. Add teams next.");
    router.push(ROUTES.projectAssignment(res.data.id));
  };

  const batchOptions = batches.map((b) => ({ label: b.name, value: b.id }));
  const installationOptions = [
    { label: "Org default", value: DEFAULT_INSTALLATION_VALUE },
    ...installations.map((i) => ({ label: i.is_default ? `${i.name} (default)` : i.name, value: i.id })),
  ];

  return (
    <Form {...form}>
      <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
        <FormSelectField control={form.control} label="Batch" name="batch_id" options={batchOptions} placeholder="Choose a batch" />
        <FormInputField control={form.control} label="Title" name="title" placeholder="Capstone: REST API Service" />
        <FormInputField control={form.control} label="Slug" name="slug" placeholder="capstone-rest-api-service" />

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

        <FormInputField
          control={form.control}
          label="Template repo path"
          name="template_project_path"
          placeholder="mindforge-templates/capstone-rest-api-starter"
        />

        {allowInstallationOverride && installations.length > 0 && (
          <FormSelectField
            control={form.control}
            description="Which GitLab connection this assignment's teams provision against."
            label="GitLab connection"
            name="installation_id"
            options={installationOptions}
          />
        )}

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
              <FormLabel className="font-normal">Protect the default branch on every team&apos;s fork</FormLabel>
            </FormItem>
          )}
        />

        <div className="grid gap-4 sm:grid-cols-2">
          <FormField
            control={form.control}
            name="starts_at"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Starts (optional)</FormLabel>
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
                <FormLabel>Due (optional)</FormLabel>
                <FormControl>
                  <Input type="datetime-local" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>

        <Button className="self-end px-5 py-2.5" disabled={form.formState.isSubmitting} type="submit">
          {form.formState.isSubmitting ? "Creating…" : "Create assignment"}
        </Button>
      </form>
    </Form>
  );
}
