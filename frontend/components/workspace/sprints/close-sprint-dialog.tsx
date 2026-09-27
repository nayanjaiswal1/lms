"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { closeSprintAction } from "@/lib/workspace/phase5-actions";
import type { Sprint, UnfinishedChoice } from "@/lib/workspace/types";

interface CloseSprintDialogProps {
  workspaceId: string;
  sprintId: string;
  nextSprints: Sprint[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** design §11: unfinished items never silently disappear on close — the
 * manager must pick carry-over (to a still-planned sprint) or backlog. */
export function CloseSprintDialog({ workspaceId, sprintId, nextSprints, open, onOpenChange }: CloseSprintDialogProps) {
  const router = useRouter();
  const [choice, setChoice] = useState<UnfinishedChoice>("backlog");
  const [nextSprintId, setNextSprintId] = useState<string>(nextSprints[0]?.id ?? "");
  const [pending, setPending] = useState(false);

  async function submit() {
    if (choice === "carry_over" && !nextSprintId) {
      toast.error("Pick a sprint to carry unfinished items into.");
      return;
    }
    setPending(true);
    const result = await closeSprintAction(workspaceId, sprintId, {
      unfinished: choice,
      next_sprint_id: choice === "carry_over" ? nextSprintId : null,
    });
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Sprint closed.");
    onOpenChange(false);
    router.refresh();
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Close sprint</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-muted-foreground">
          Any item still open in this sprint needs somewhere to go — pick one.
        </p>
        <RadioGroup value={choice} onValueChange={(v) => setChoice(v as UnfinishedChoice)}>
          <label className="flex items-center gap-2 text-sm" htmlFor="unfinished-backlog">
            <RadioGroupItem id="unfinished-backlog" value="backlog" /> Move unfinished items to the backlog
          </label>
          <label className="flex items-center gap-2 text-sm" htmlFor="unfinished-carry-over">
            <RadioGroupItem disabled={nextSprints.length === 0} id="unfinished-carry-over" value="carry_over" />
            Carry over to another planned sprint
          </label>
        </RadioGroup>
        {choice === "carry_over" && (
          <Select value={nextSprintId} onValueChange={setNextSprintId}>
            <SelectTrigger><SelectValue placeholder="Pick a sprint" /></SelectTrigger>
            <SelectContent>
              {nextSprints.map((s) => (
                <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        <DialogFooter>
          <Button disabled={pending} onClick={submit}>
            {pending ? "Closing…" : "Close sprint"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
