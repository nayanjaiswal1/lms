"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Trash2 } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { CreateOnboardingStepDialog } from "@/components/workspace/create-onboarding-step-dialog";
import { deleteOnboardingStepAction, setOnboardingStepDoneAction } from "@/lib/workspace/actions";
import type { OnboardingStep } from "@/lib/workspace/types";

interface OnboardingChecklistProps {
  workspaceId: string;
  steps: OnboardingStep[];
  /** member+ can check off their own steps; viewers are read-only. */
  canComplete: boolean;
  canManage: boolean;
}

export function OnboardingChecklist({ workspaceId, steps, canComplete, canManage }: OnboardingChecklistProps) {
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<OnboardingStep | null>(null);
  const doneCount = steps.filter((s) => s.done_at).length;

  async function handleToggle(step: OnboardingStep, done: boolean) {
    setPendingId(step.id);
    const result = await setOnboardingStepDoneAction(workspaceId, step.id, done);
    setPendingId(null);
    if (result.error) toast.error(result.error);
  }

  async function handleDelete(step: OnboardingStep) {
    setPendingId(step.id);
    const result = await deleteOnboardingStepAction(workspaceId, step.id);
    setPendingId(null);
    setDeleteTarget(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Step removed.");
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          {doneCount} of {steps.length} complete
        </p>
        {canManage && <CreateOnboardingStepDialog nextPosition={steps.length} workspaceId={workspaceId} />}
      </div>

      {steps.length === 0 ? (
        <div className="empty-state">
          <p className="font-medium text-muted-foreground">No onboarding steps yet.</p>
        </div>
      ) : (
        <ul className="flex flex-col gap-2">
          {steps.map((step) => (
            <li className="card-base flex items-center gap-3" key={step.id}>
              <Checkbox
                aria-label={step.title}
                checked={step.done_at !== null}
                disabled={!canComplete || pendingId === step.id}
                onCheckedChange={(checked) => handleToggle(step, checked === true)}
              />
              <span className="flex-1 truncate">{step.title}</span>
              {step.required && <Badge variant="outline">Required</Badge>}
              {canManage && (
                <Button
                  aria-label={`Delete ${step.title}`}
                  disabled={pendingId === step.id}
                  size="icon"
                  variant="ghost"
                  onClick={() => setDeleteTarget(step)}
                >
                  <Trash2 aria-hidden className="h-4 w-4" />
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}

      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description={deleteTarget ? `"${deleteTarget.title}" will be removed for everyone.` : ""}
        open={deleteTarget !== null}
        pending={deleteTarget !== null && pendingId === deleteTarget.id}
        title={deleteTarget ? `Delete "${deleteTarget.title}"?` : "Delete step?"}
        onConfirm={() => deleteTarget && handleDelete(deleteTarget)}
        onOpenChange={(open) => !open && setDeleteTarget(null)}
      />
    </div>
  );
}
