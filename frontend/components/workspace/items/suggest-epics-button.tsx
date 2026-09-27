"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { CreateItemDialog } from "@/components/workspace/items/create-item-dialog";
import { suggestEpicsAction } from "@/lib/workspace/phase5-actions";
import type { SuggestedItem, Track } from "@/lib/workspace/types";

interface SuggestEpicsButtonProps {
  workspaceId: string;
  tracks: Track[];
}

/** contract-phase5.md 5c: manager+, brief agreed — a first pass at epic/
 * feature breakdown from the requirement text. Suggest-only: each "Create"
 * still goes through CreateItemDialog's normal create path. */
export function SuggestEpicsButton({ workspaceId, tracks }: SuggestEpicsButtonProps) {
  const [items, setItems] = useState<SuggestedItem[] | null>(null);
  const [pending, startTransition] = useTransition();

  function suggest() {
    startTransition(async () => {
      const result = await suggestEpicsAction(workspaceId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setItems(result.data?.items ?? []);
    });
  }

  return (
    <>
      <Button className="text-ai gap-2" disabled={pending} variant="outline" onClick={suggest}>
        <Sparkles aria-hidden className="h-4 w-4" />
        {pending ? "Thinking…" : "Suggest epics (AI)"}
      </Button>
      <Dialog open={items !== null} onOpenChange={(o) => !o && setItems(null)}>
        <DialogContent className="modal-responsive">
          <DialogHeader>
            <DialogTitle>AI-suggested epics &amp; features</DialogTitle>
          </DialogHeader>
          <div className="ai-surface flex max-h-[60vh] flex-col gap-2 overflow-y-auto">
            <p className="ai-badge w-fit">AI suggestion</p>
            {items?.length === 0 && <p className="text-sm text-muted-foreground">No suggestions.</p>}
            {items?.map((s, i) => (
              <div className="flex items-center justify-between gap-3 border-b border-border pb-2 last:border-0" key={i}>
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">
                    <span className="text-xs uppercase text-muted-foreground">{s.type}</span> {s.title}
                  </p>
                  <p className="text-xs text-muted-foreground">{s.description}</p>
                </div>
                <CreateItemDialog
                  allowedTypes={[s.type]}
                  defaultDescription={s.description}
                  defaultTitle={s.title}
                  defaultType={s.type}
                  tracks={tracks}
                  triggerLabel="Create"
                  workspaceId={workspaceId}
                />
              </div>
            ))}
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
