"use client";

import { useState, useTransition } from "react";
import { FileText, Image as ImageIcon, Link2, RotateCcw, X } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { CaptureStatusBadge } from "@/components/captures/capture-status-badge";
import { CapturePromoteDialog } from "@/components/captures/capture-promote-dialog";
import { dismissCaptureAction, retryCaptureAction } from "@/app/(app)/captures/actions";
import type { Capture } from "@/lib/server/captures";

const TYPE_ICON = { image: ImageIcon, pdf: FileText, link: Link2, html: Link2 } as const;

export function CaptureCard({ capture }: { capture: Capture }) {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const TypeIcon = TYPE_ICON[capture.type];

  function retry() {
    startTransition(async () => {
      const result = await retryCaptureAction(capture.id);
      if (!result.ok) toast.error(result.error ?? "Couldn't retry this capture.");
    });
  }

  function dismiss() {
    startTransition(async () => {
      const result = await dismissCaptureAction(capture.id);
      if (!result.ok) toast.error(result.error ?? "Couldn't dismiss this capture.");
    });
  }

  return (
    <div className="card-base flex flex-col gap-2 p-4">
      <div className="flex items-start justify-between gap-2">
        <div className="flex min-w-0 items-center gap-2">
          <TypeIcon aria-hidden className="size-4 shrink-0 text-muted-foreground" />
          <p className="truncate text-sm font-semibold leading-snug text-foreground">
            {capture.title ?? capture.source_url ?? "Untitled capture"}
          </p>
        </div>
        <CaptureStatusBadge status={capture.status} />
      </div>

      {capture.status === "ready" && capture.content && (
        <p className="line-clamp-2 text-sm text-muted-foreground">{capture.content}</p>
      )}
      {capture.status === "failed" && capture.error_message && (
        <p className="text-sm text-destructive">{capture.error_message}</p>
      )}

      <div className="flex justify-end gap-2">
        {capture.status === "ready" && (
          <Button size="sm" onClick={() => setDialogOpen(true)}>
            Review
          </Button>
        )}
        {capture.status === "failed" && (
          <Button disabled={isPending} size="sm" variant="outline" onClick={retry}>
            <RotateCcw aria-hidden className="size-4" />
            Retry
          </Button>
        )}
        {capture.status !== "promoted" && capture.status !== "dismissed" && (
          <Button aria-label="Dismiss" className="touch-target" disabled={isPending} size="icon" variant="ghost" onClick={dismiss}>
            <X aria-hidden className="size-4" />
          </Button>
        )}
      </div>

      <CapturePromoteDialog capture={capture} open={dialogOpen} onOpenChange={setDialogOpen} />
    </div>
  );
}
