"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Form } from "@/components/ui/form";
import { FormCheckboxField } from "@/components/ui/form-checkbox-field";
import { FormSelectField } from "@/components/ui/form-select-field";
import { FormTextareaField } from "@/components/ui/form-textarea-field";
import { ItemSearchPicker } from "@/components/workspace/items/item-search-picker";
import { triageBugAction } from "@/lib/workspace/phase3-actions";
import type { BugSeverity, Member, TriageDecision, WorkItem } from "@/lib/workspace/types";

const DECISION_OPTIONS: { label: string; value: TriageDecision }[] = [
  { label: "Duplicate", value: "duplicate" },
  { label: "Not a bug", value: "not_a_bug" },
  { label: "Confirmed", value: "confirmed" },
];

const SEVERITY_OPTIONS: { label: string; value: BugSeverity }[] = [
  { label: "S1 — Critical", value: "S1" },
  { label: "S2 — Major", value: "S2" },
  { label: "S3 — Minor", value: "S3" },
  { label: "S4 — Trivial", value: "S4" },
];

const Schema = z.object({
  decision: z.enum(["duplicate", "not_a_bug", "confirmed"]),
  severity: z.enum(["S1", "S2", "S3", "S4"]).optional(),
  reason: z.string().max(2000).optional(),
  owner_user_id: z.string().optional(),
  is_regression: z.boolean().optional(),
});
type FormData = z.infer<typeof Schema>;

interface TriageDialogProps {
  workspaceId: string;
  bug: WorkItem;
  members: Member[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onTriaged: (bugId: string) => void;
}

/** One dialog for all three TriageBugRequest decisions — the field set
 * (duplicate target / reason / severity+owner+parent) is decision-specific,
 * not a single fixed form, so it's driven off `decision` rather than reusing
 * CreateItemDialog's shape wholesale. */
export function TriageDialog({ workspaceId, bug, members, open, onOpenChange, onTriaged }: TriageDialogProps) {
  const [duplicateOf, setDuplicateOf] = useState<WorkItem | null>(null);
  const [parent, setParent] = useState<WorkItem | null>(null);
  const form = useForm<FormData>({
    resolver: zodResolver(Schema),
    defaultValues: { decision: "confirmed", is_regression: false },
  });
  const decision = form.watch("decision");
  const activeMembers = members.filter((m) => m.status === "active");

  function reset() {
    form.reset({ decision: "confirmed", is_regression: false });
    setDuplicateOf(null);
    setParent(null);
  }

  async function onSubmit(data: FormData) {
    if (data.decision === "duplicate" && !duplicateOf) {
      toast.error("Pick the item this duplicates.");
      return;
    }
    if (data.decision === "not_a_bug" && !data.reason?.trim()) {
      toast.error("A reason is required.");
      return;
    }
    if (data.decision === "confirmed" && !data.severity) {
      toast.error("Pick a severity.");
      return;
    }

    const result = await triageBugAction(workspaceId, bug.id, {
      decision: data.decision,
      severity: data.decision === "confirmed" ? data.severity : undefined,
      duplicate_of_id: data.decision === "duplicate" ? (duplicateOf?.id ?? undefined) : undefined,
      reason: data.reason?.trim() || undefined,
      owner_user_id: data.decision === "confirmed" ? (data.owner_user_id || undefined) : undefined,
      is_regression: data.decision === "confirmed" ? data.is_regression : undefined,
      parent_id: data.decision === "confirmed" ? (parent?.id ?? undefined) : undefined,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Bug triaged.");
    onTriaged(bug.id);
    onOpenChange(false);
    reset();
  }

  return (
    <Dialog open={open} onOpenChange={(o) => { onOpenChange(o); if (!o) reset(); }}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Triage {bug.key}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form className="form-stack" onSubmit={form.handleSubmit(onSubmit)}>
            <FormSelectField control={form.control} label="Decision" name="decision" options={DECISION_OPTIONS} />

            {decision === "duplicate" && (
              <div className="flex flex-col gap-1.5">
                <span className="text-sm font-medium">Duplicate of</span>
                <ItemSearchPicker
                  excludeItemId={bug.id}
                  placeholder="Search for the original item…"
                  value={duplicateOf}
                  workspaceId={workspaceId}
                  onChange={setDuplicateOf}
                />
              </div>
            )}

            {decision === "not_a_bug" && (
              <FormTextareaField control={form.control} label="Reason" name="reason" rows={3} />
            )}

            {decision === "confirmed" && (
              <>
                <FormSelectField control={form.control} label="Severity" name="severity" options={SEVERITY_OPTIONS} placeholder="Select severity" />
                <FormSelectField
                  control={form.control}
                  label="Owner (optional)"
                  name="owner_user_id"
                  options={activeMembers.map((m) => ({ label: m.name, value: m.user_id }))}
                  placeholder="Unassigned"
                />
                <div className="flex flex-col gap-1.5">
                  <span className="text-sm font-medium">Move under (optional)</span>
                  <ItemSearchPicker
                    excludeItemId={bug.id}
                    filterTypes={["epic", "feature"]}
                    placeholder="Search epics / features…"
                    value={parent}
                    workspaceId={workspaceId}
                    onChange={setParent}
                  />
                </div>
                <FormCheckboxField control={form.control} label="This is a regression" name="is_regression" />
              </>
            )}

            <DialogFooter>
              <Button disabled={form.formState.isSubmitting} type="submit">
                {form.formState.isSubmitting ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
