"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { getReleaseNotesAction } from "@/lib/workspace/phase5-actions";
import type { ReleaseNotes } from "@/lib/workspace/types";

interface ReleaseNotesButtonProps {
  workspaceId: string;
  releaseId: string;
}

/** Fetches on click (never a useEffect-on-open) — the dialog's own open
 * state is derived from whether a fetch is in flight or has data. */
export function ReleaseNotesButton({ workspaceId, releaseId }: ReleaseNotesButtonProps) {
  const { atLeast } = useProjectRole();
  const [notes, setNotes] = useState<ReleaseNotes | null>(null);
  const [loading, setLoading] = useState(false);

  async function load(polish: boolean) {
    setLoading(true);
    const result = await getReleaseNotesAction(workspaceId, releaseId, polish);
    setLoading(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    setNotes(result.data ?? null);
  }

  return (
    <>
      <Button size="sm" variant="outline" onClick={() => void load(false)}>
        Release notes
      </Button>
      <Dialog open={loading || notes !== null} onOpenChange={(o) => !o && setNotes(null)}>
        <DialogContent className="modal-responsive">
          <DialogHeader><DialogTitle>Release notes</DialogTitle></DialogHeader>
          {loading && <p className="text-sm text-muted-foreground">Loading…</p>}
          {!loading && notes && (
            <div className="flex max-h-[60vh] flex-col gap-4 overflow-y-auto">
              {notes.polished ? (
                <div className="ai-surface flex flex-col gap-1">
                  <p className="ai-badge w-fit">AI-polished</p>
                  <p className="whitespace-pre-wrap text-sm">{notes.polished}</p>
                </div>
              ) : (
                atLeast("manager") && (
                  <Button className="w-fit gap-2 text-ai" variant="outline" onClick={() => void load(true)}>
                    <Sparkles aria-hidden className="h-4 w-4" />
                    Polish with AI
                  </Button>
                )
              )}
              <div className="flex flex-col gap-1">
                <p className="text-sm font-medium">Shipped items ({notes.items.length})</p>
                {notes.items.map((it) => (
                  <div className="flex items-center justify-between border-b border-border py-1.5 text-sm last:border-0" key={it.item.id}>
                    <span className="truncate">
                      <span className="text-xs uppercase text-muted-foreground">{it.item.type}</span> {it.item.title}
                    </span>
                    {it.doc_version !== null && <span className="text-xs text-muted-foreground">doc v{it.doc_version}</span>}
                  </div>
                ))}
                {notes.items.length === 0 && <p className="text-sm text-muted-foreground">Nothing targets this release yet.</p>}
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
