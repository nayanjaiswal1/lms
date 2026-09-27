"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Copy, RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { rotateShareTokenAction } from "@/lib/workspace/actions";

interface ShareLinkSectionProps {
  workspaceId: string;
  shareToken?: string;
}

export function ShareLinkSection({ workspaceId, shareToken }: ShareLinkSectionProps) {
  const [pending, setPending] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const joinUrl = shareToken
    ? `${typeof window !== "undefined" ? window.location.origin : ""}/join/${shareToken}`
    : null;

  async function handleRotate() {
    setPending(true);
    const result = await rotateShareTokenAction(workspaceId);
    setPending(false);
    setConfirmOpen(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Share link rotated — the old link no longer works.");
  }

  async function copyLink() {
    if (!joinUrl) return;
    await navigator.clipboard.writeText(joinUrl);
    toast.success("Share link copied.");
  }

  return (
    <div className="card-base flex flex-col gap-3">
      <h2 className="subsection-title">Share link</h2>
      <p className="text-sm text-muted-foreground">Anyone with this link can express interest in joining the project.</p>
      <div className="flex flex-col gap-2 sm:flex-row">
        <Input readOnly className="font-mono text-xs" value={joinUrl ?? "No active link"} />
        <div className="flex gap-2">
          <Button aria-label="Copy share link" disabled={!joinUrl} size="icon" variant="outline" onClick={copyLink}>
            <Copy aria-hidden className="h-4 w-4" />
          </Button>
          <Button aria-label="Rotate share link" disabled={pending} size="icon" variant="outline" onClick={() => setConfirmOpen(true)}>
            <RefreshCw aria-hidden className="h-4 w-4" />
          </Button>
        </div>
      </div>
      <ConfirmDialog
        description="The current share link stops working immediately. Anyone who has it will see a 404."
        open={confirmOpen}
        pending={pending}
        title="Rotate share link?"
        onConfirm={handleRotate}
        onOpenChange={setConfirmOpen}
      />
    </div>
  );
}
