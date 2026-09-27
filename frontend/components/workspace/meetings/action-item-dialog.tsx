"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { DuplicateCheckPanel } from "@/components/workspace/items/duplicate-check-panel";
import { convertActionItemAction } from "@/lib/workspace/phase3-actions";
import type { Meeting, SimilarItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface ActionItemDialogProps {
  workspaceId: string;
  meeting: Meeting;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** "Convert to ticket" for a meeting action item — mirrors create-item-dialog's
 * duplicate-check UX, but the check runs server-side on submit (ListSimilarItems,
 * contract-phase3.md's ConvertActionItem) instead of a debounced live search,
 * since there's no title field to watch until the manager starts typing one
 * anyway. A first submit with hits and Force=false creates nothing (item.id
 * is empty) — "Create anyway" resubmits the same input with force:true. */
export function ActionItemDialog({ workspaceId, meeting, open, onOpenChange }: ActionItemDialogProps) {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [similar, setSimilar] = useState<SimilarItem[] | null>(null);
  const [pending, setPending] = useState(false);

  function reset() {
    setTitle("");
    setDescription("");
    setSimilar(null);
  }

  async function submit(force: boolean) {
    if (title.trim().length < 3) {
      toast.error("Give the ticket a title.");
      return;
    }
    setPending(true);
    const result = await convertActionItemAction(workspaceId, meeting.calendar_event_id, {
      title: title.trim(),
      description: description.trim() || undefined,
      force,
    });
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    if (result.data?.item.id) {
      toast.success(`${result.data.item.key} created.`);
      onOpenChange(false);
      reset();
      router.push(ROUTES.workspaceItem(workspaceId, result.data.item.key));
      return;
    }
    setSimilar(result.data?.similar ?? []);
  }

  return (
    <Dialog open={open} onOpenChange={(o) => { onOpenChange(o); if (!o) reset(); }}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Convert action item to ticket</DialogTitle>
          <DialogDescription>From “{meeting.title}”. Similar open items are checked before creating.</DialogDescription>
        </DialogHeader>
        <div className="form-stack">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium" htmlFor="action-item-title">Title</label>
            <Input
              id="action-item-title"
              placeholder="Short, specific summary"
              value={title}
              onChange={(e) => { setTitle(e.target.value); setSimilar(null); }}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium" htmlFor="action-item-description">Description (optional)</label>
            <Textarea id="action-item-description" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>

          {similar && similar.length > 0 && (
            <>
              <DuplicateCheckPanel searching={false} similar={similar} workspaceId={workspaceId} />
              <p className="text-sm text-muted-foreground">Still create a new ticket?</p>
            </>
          )}
        </div>
        <DialogFooter>
          {similar && similar.length > 0 ? (
            <Button disabled={pending} variant="outline" onClick={() => void submit(true)}>
              {pending ? "Creating…" : "Create anyway"}
            </Button>
          ) : (
            <Button disabled={pending} onClick={() => void submit(false)}>
              {pending ? "Checking…" : "Create ticket"}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
