"use client";

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
import type { WorkItem } from "@/lib/workspace/types";

export interface ConflictField {
  label: string;
  yours: string;
  current: string;
}

interface ConflictDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The current row the backend returned on the 409 (ActionResult.conflict). */
  current: WorkItem | null;
  /** Only the fields the caller was actually editing — see 04-frontend.md §7 "Stale edit". */
  fields: ConflictField[];
  /** Owner/manager only — resubmits with `current.version`. */
  canOverwrite: boolean;
  pending: boolean;
  onReload: () => void;
  onOverwrite: (currentVersion: number) => void;
}

/** Shown whenever an update/move/transition 409s because someone else changed
 * the item first (D17: ActionResult.conflict carries the current row). */
export function ConflictDialog({ open, onOpenChange, current, fields, canOverwrite, pending, onReload, onOverwrite }: ConflictDialogProps) {
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent className="modal-responsive">
        <AlertDialogHeader>
          <AlertDialogTitle>Someone else changed this item</AlertDialogTitle>
          <AlertDialogDescription>
            {current
              ? `It's now at version ${current.version}. Review what changed before deciding how to proceed.`
              : "It changed while you were editing. Reload to see the latest."}
          </AlertDialogDescription>
        </AlertDialogHeader>

        {fields.length > 0 && (
          <div className="flex flex-col gap-2 rounded-md border border-border p-3 text-sm">
            {fields.map((f) => (
              <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] gap-2" key={f.label}>
                <div className="min-w-0">
                  <p className="text-xs font-medium text-muted-foreground">{f.label} — yours</p>
                  <p className="truncate">{f.yours || "—"}</p>
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-medium text-muted-foreground">{f.label} — current</p>
                  <p className="truncate">{f.current || "—"}</p>
                </div>
              </div>
            ))}
          </div>
        )}

        <AlertDialogFooter>
          <AlertDialogCancel disabled={pending} onClick={onReload}>
            Reload current
          </AlertDialogCancel>
          {canOverwrite && current && (
            <AlertDialogAction disabled={pending} onClick={() => onOverwrite(current.version)}>
              {pending ? "Overwriting…" : "Overwrite anyway"}
            </AlertDialogAction>
          )}
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
