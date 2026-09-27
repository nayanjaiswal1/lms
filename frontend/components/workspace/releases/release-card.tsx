"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ReleaseNotesButton } from "@/components/workspace/releases/release-notes-dialog";
import { updateReleaseAction } from "@/lib/workspace/phase5-actions";
import type { Release, ReleaseStatus } from "@/lib/workspace/types";

const STATUS_VARIANT: Record<ReleaseStatus, "default" | "secondary" | "outline"> = {
  planned: "outline",
  frozen: "secondary",
  released: "default",
};

export function ReleaseCard({ workspaceId, release, canManage }: { workspaceId: string; release: Release; canManage: boolean }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function setStatus(status: ReleaseStatus) {
    startTransition(async () => {
      const result = await updateReleaseAction(workspaceId, release.id, { status });
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success(`Release ${status}.`);
      router.refresh();
    });
  }

  const allFeaturesDone = release.features_total === 0 || release.features_done === release.features_total;

  return (
    <div className="card-base flex flex-col gap-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <p className="font-medium">{release.version}</p>
            <Badge variant={STATUS_VARIANT[release.status]}>{release.status}</Badge>
          </div>
          {release.target_at && (
            <p className="text-xs text-muted-foreground">Target: {new Date(release.target_at).toLocaleDateString()}</p>
          )}
        </div>
        <div className="flex gap-2">
          <ReleaseNotesButton releaseId={release.id} workspaceId={workspaceId} />
          {canManage && release.status === "planned" && (
            <Button disabled={pending} size="sm" onClick={() => setStatus("frozen")}>
              Freeze
            </Button>
          )}
          {canManage && release.status === "frozen" && (
            <>
              <Button disabled={pending} size="sm" variant="outline" onClick={() => setStatus("planned")}>
                Unfreeze
              </Button>
              <Button disabled={pending} size="sm" onClick={() => setStatus("released")}>
                Release
              </Button>
            </>
          )}
        </div>
      </div>

      <div className="grid-stats">
        <div>
          <p className="text-xs text-muted-foreground">Features</p>
          <p className={`text-sm font-medium ${allFeaturesDone ? "text-success" : ""}`}>
            {release.features_done}/{release.features_total} done
          </p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Open bugs</p>
          <p className="text-sm font-medium">{release.open_bugs}</p>
        </div>
      </div>
    </div>
  );
}
