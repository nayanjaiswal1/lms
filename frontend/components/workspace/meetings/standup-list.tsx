"use client";

import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import type { Standup } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface StandupListProps {
  workspaceId: string;
  standups: Standup[];
}

/** Read-only — today's standups from everyone. BlockerKeys are resolved
 * ticket links only, no status change (models_phase3.go D12). */
export function StandupList({ workspaceId, standups }: StandupListProps) {
  if (standups.length === 0) {
    return <p className="text-sm text-muted-foreground">No standups posted today yet.</p>;
  }

  return (
    <ul className="flex flex-col gap-3">
      {standups.map((s) => (
        <li className="card-base flex flex-col gap-1.5" key={s.user_id}>
          <p className="text-sm font-medium">{s.name}</p>
          <p className="text-sm"><span className="text-muted-foreground">Yesterday:</span> {s.yesterday}</p>
          <p className="text-sm"><span className="text-muted-foreground">Today:</span> {s.today}</p>
          {s.blockers && (
            <div className="flex flex-wrap items-center gap-1.5 text-sm">
              <span className="text-muted-foreground">Blockers:</span> {s.blockers}
              {s.blocker_keys.map((ref) => (
                <Link href={ROUTES.workspaceItem(workspaceId, ref.key)} key={ref.id}>
                  <Badge variant="destructive">{ref.key}</Badge>
                </Link>
              ))}
            </div>
          )}
        </li>
      ))}
    </ul>
  );
}
