import Link from "next/link";
import { AlertTriangle } from "lucide-react";

import ROUTES from "@/lib/routes";
import type { Track } from "@/lib/workspace/types";

interface LeaderlessTracksBannerProps {
  workspaceId: string;
  tracks: Track[];
}

// contract-phase4.md 4c: a track loses its lead when they leave/are removed;
// new assignments against that track are blocked (ErrTrackLeaderless) until a
// manager sets a new one. Surfaced here so managers see it without having to
// discover the block the next time they try to assign someone.
export function LeaderlessTracksBanner({ workspaceId, tracks }: LeaderlessTracksBannerProps) {
  const leaderless = tracks.filter((t) => t.lead_user_id === null);
  if (leaderless.length === 0) return null;

  return (
    <div className="card-base flex items-start gap-3 border-warning/30 bg-warning/10 p-4">
      <AlertTriangle aria-hidden className="mt-0.5 h-5 w-5 shrink-0 text-warning-foreground" />
      <div className="flex flex-col gap-1 text-sm">
        <p className="font-medium text-foreground">
          {leaderless.length === 1 ? "1 track has no lead" : `${leaderless.length} tracks have no lead`}
        </p>
        <p className="text-muted-foreground">
          New assignments are blocked on {leaderless.map((t) => t.name).join(", ")} until a lead is set.{" "}
          <Link className="underline underline-offset-2" href={ROUTES.workspaceTracks(workspaceId)}>
            Set a lead
          </Link>
        </p>
      </div>
    </div>
  );
}
