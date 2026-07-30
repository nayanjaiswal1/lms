"use client";

import { useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { MoreVertical, Settings, Users, ArrowRightLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { setAssessmentStatusAction, assignAssessmentAction } from "@/app/(app)/assessments/actions";
import { ASSESSMENT_MANUAL_STATUS_OPTIONS } from "@/lib/constants";
import ROUTES from "@/lib/routes";
import type { Assessment, Batch } from "@/lib/assessments/types";

interface AssessmentCardMenuProps {
  assessment: Assessment;
  batches: Batch[];
}

// Row-level actions for the assessment list — everything here used to require
// opening the assessment's own manage page first. "Edit settings" jumps
// straight to the config editor (not the question builder, which stays a
// click on the card title); status moves and batch assignment happen inline.
export function AssessmentCardMenu({ assessment, batches }: AssessmentCardMenuProps) {
  const [ui, setUi] = useState<{ dialog: "assign" | "status" | null; targetStatus: string | null; pending: boolean }>({
    dialog: null,
    targetStatus: null,
    pending: false,
  });
  const [selectedBatches, setSelectedBatches] = useState<string[]>([]);

  const statusOptions = ASSESSMENT_MANUAL_STATUS_OPTIONS.filter((o) => o.value !== assessment.status);
  const targetOption = ASSESSMENT_MANUAL_STATUS_OPTIONS.find((o) => o.value === ui.targetStatus);

  const closeDialog = () => setUi({ dialog: null, targetStatus: null, pending: false });

  const confirmStatusChange = async () => {
    if (!ui.targetStatus) return;
    setUi((s) => ({ ...s, pending: true }));
    const res = await setAssessmentStatusAction(assessment.id, ui.targetStatus);
    if (res.error) {
      toast.error(res.error);
      setUi((s) => ({ ...s, pending: false }));
      return;
    }
    toast.success(`Moved to ${targetOption?.label ?? ui.targetStatus}.`);
    closeDialog();
  };

  const toggleBatch = (id: string, on: boolean) =>
    setSelectedBatches((prev) => (on ? [...prev, id] : prev.filter((b) => b !== id)));

  const confirmAssign = async () => {
    setUi((s) => ({ ...s, pending: true }));
    const res = await assignAssessmentAction(assessment.id, "batch", selectedBatches);
    if (res.error) {
      toast.error(res.error);
      setUi((s) => ({ ...s, pending: false }));
      return;
    }
    toast.success("Assigned to batches.");
    setSelectedBatches([]);
    closeDialog();
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            aria-label={`${assessment.title} options`}
            className="touch-target shrink-0"
            size="icon"
            variant="ghost"
            onClick={(e) => e.stopPropagation()}
          >
            <MoreVertical aria-hidden className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
          <DropdownMenuItem asChild>
            <Link href={`${ROUTES.assessmentEdit(assessment.id)}?tab=settings`}>
              <Settings aria-hidden className="h-4 w-4" /> Edit settings
            </Link>
          </DropdownMenuItem>
          <DropdownMenuItem
            disabled={batches.length === 0}
            onSelect={() => {
              setSelectedBatches([]);
              setUi({ dialog: "assign", targetStatus: null, pending: false });
            }}
          >
            <Users aria-hidden className="h-4 w-4" /> Assign to batch
          </DropdownMenuItem>
          {statusOptions.length > 0 && (
            <>
              <DropdownMenuSeparator />
              <DropdownMenuSub>
                <DropdownMenuSubTrigger>
                  <ArrowRightLeft aria-hidden className="h-4 w-4" /> Move to…
                </DropdownMenuSubTrigger>
                <DropdownMenuSubContent>
                  {statusOptions.map((o) => (
                    <DropdownMenuItem
                      key={o.value}
                      onSelect={() => setUi({ dialog: "status", targetStatus: o.value, pending: false })}
                    >
                      {o.label}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuSubContent>
              </DropdownMenuSub>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      <Dialog open={ui.dialog === "assign"} onOpenChange={(open) => !open && closeDialog()}>
        <DialogContent className="modal-responsive sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Assign &quot;{assessment.title}&quot; to batches</DialogTitle>
          </DialogHeader>
          <div className="flex flex-wrap gap-3">
            {batches.map((b) => (
              <Label className="card-base flex cursor-pointer items-center gap-2 p-3 font-normal" key={b.id}>
                <Checkbox
                  checked={selectedBatches.includes(b.id)}
                  disabled={ui.pending}
                  onCheckedChange={(c) => toggleBatch(b.id, Boolean(c))}
                />
                {b.name} <span className="text-xs text-muted-foreground">({b.member_count})</span>
              </Label>
            ))}
          </div>
          <DialogFooter>
            <Button disabled={ui.pending} type="button" variant="outline" onClick={closeDialog}>
              Cancel
            </Button>
            <Button disabled={ui.pending || selectedBatches.length === 0} onClick={confirmAssign}>
              {ui.pending ? "Assigning…" : `Assign ${selectedBatches.length > 0 ? `(${selectedBatches.length})` : ""}`}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <AlertDialog open={ui.dialog === "status"} onOpenChange={(open) => !open && closeDialog()}>
        <AlertDialogContent className="modal-responsive">
          <AlertDialogHeader>
            <AlertDialogTitle>Move to {targetOption?.label}?</AlertDialogTitle>
            <AlertDialogDescription>
              {targetOption?.description}
              {(assessment.status === "active" || assessment.status === "published") &&
                " This assessment currently has students actively taking it — moving it will change what they see immediately."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={ui.pending}>Cancel</AlertDialogCancel>
            <AlertDialogAction disabled={ui.pending} onClick={confirmStatusChange}>
              {ui.pending ? "Moving…" : "Move"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
