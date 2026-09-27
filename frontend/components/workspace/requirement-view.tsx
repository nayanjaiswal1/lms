"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { updateRequirementAction } from "@/lib/workspace/actions";
import { BRIEF_STATUS_LABEL } from "@/lib/workspace/roles";
import type { RequirementView as RequirementViewData } from "@/lib/workspace/types";

const Schema = z.object({
  requirement: z.string().min(50, "At least 50 characters.").max(20000),
});
type FormData = z.infer<typeof Schema>;

interface RequirementViewProps {
  workspaceId: string;
  requirement: RequirementViewData;
  canEdit: boolean;
}

export function RequirementView({ workspaceId, requirement, canEdit }: RequirementViewProps) {
  const [editing, setEditing] = useState(false);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { requirement: requirement.requirement },
  });

  async function onSubmit(data: FormData) {
    const result = await updateRequirementAction(workspaceId, data.requirement);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Requirement updated — a new version was recorded.");
    setEditing(false);
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Badge variant="outline">v{requirement.requirement_version}</Badge>
          <Badge variant="secondary">{BRIEF_STATUS_LABEL[requirement.brief_status]}</Badge>
        </div>
        {canEdit && !editing && (
          <Button size="sm" variant="outline" onClick={() => setEditing(true)}>
            Edit
          </Button>
        )}
      </div>

      {editing ? (
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormTextareaField control={form.control} name="requirement" rows={12} />
            <div className="flex justify-end gap-2">
              <Button
                disabled={form.formState.isSubmitting}
                type="button"
                variant="outline"
                onClick={() => {
                  form.reset({ requirement: requirement.requirement });
                  setEditing(false);
                }}
              >
                Cancel
              </Button>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Saving…" : "Save new version"}
              </Button>
            </div>
          </form>
        </Form>
      ) : (
        <p className="prose-content whitespace-pre-wrap">{requirement.requirement}</p>
      )}

      {requirement.versions.length > 1 && (
        <div className="flex flex-col gap-2">
          <h2 className="subsection-title">Version history</h2>
          <ul className="flex flex-col gap-2">
            {requirement.versions
              .slice()
              .sort((a, b) => b.version - a.version)
              .map((version) => (
                <li className="card-base" key={version.version}>
                  <details>
                    <summary className="cursor-pointer text-sm font-medium">
                      v{version.version} — {new Date(version.created_at).toLocaleString()}
                    </summary>
                    <p className="prose-content mt-2 whitespace-pre-wrap text-sm text-muted-foreground">
                      {version.raw_requirement}
                    </p>
                  </details>
                </li>
              ))}
          </ul>
        </div>
      )}
    </div>
  );
}
