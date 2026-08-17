"use client";

import { useState, useEffect } from "react";
import { Badge } from "@/components/ui/badge";
import type { WorkerHealthResponse } from "@/lib/jobs/admin-server";

interface Props {
  initialData: WorkerHealthResponse;
}

function relativeTime(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const secs = Math.floor(diffMs / 1000);
  if (secs < 60) return `${secs}s ago`;
  const mins = Math.floor(secs / 60);
  if (mins < 60) return `${mins}m ago`;
  return `${Math.floor(mins / 60)}h ago`;
}

export function WorkersClient({ initialData }: Props) {
  const [data, setData] = useState<WorkerHealthResponse>(initialData);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  // justification: auto-refresh worker health every 15s for live monitoring
  useEffect(() => {
    const id = setInterval(async () => {
      try {
        const res = await fetch("/api/admin/jobs/workers", {
          credentials: "include",
          cache: "no-store",
        });
        if (!res.ok) return;
        const json = (await res.json()) as { data: WorkerHealthResponse };
        setData(json.data);
      } catch {
        // network error — keep showing stale data
      }
    }, 15_000);
    return () => clearInterval(id);
  }, []);

  return (
    <div>
      {/* table-responsive belongs on the table alone (border/rounded box +
          horizontal scroll) — it was wrapping the summary line below too,
          so that text sat flush inside the table's own border with no
          padding of its own instead of living outside it as a caption. */}
      <div className="table-responsive">
        {/* table-layout: fixed + explicit column widths — with `auto` layout
            and few rows, the browser spread leftover width arbitrarily
            (huge gap after the instance ID, an oversized progress bar). */}
        <table className="w-full table-fixed text-sm">
          <thead>
            <tr className="border-b border-border text-left text-muted-foreground">
              <th className="w-56 pt-3 pb-2 pl-4 pr-6 font-medium">Instance ID</th>
              <th className="w-48 pt-3 pb-2 pr-6 font-medium">Slots</th>
              <th className="w-28 pt-3 pb-2 pr-6 font-medium">Last Seen</th>
              <th className="pt-3 pb-2 pr-4 font-medium">Role</th>
            </tr>
          </thead>
          <tbody>
            {data.workers.map((worker) => {
              const pct =
                worker.slots_total > 0
                  ? Math.round((worker.slots_busy / worker.slots_total) * 100)
                  : 0;
              const isLeader = worker.instance_id === data.leader;

              return (
                <tr key={worker.instance_id} className="border-b border-border last:border-0">
                  <td className="py-3 pl-4 pr-6">
                    <span className="font-mono text-xs">{worker.instance_id}</span>
                  </td>
                  <td className="py-3 pr-6">
                    {/* eslint-disable-next-line no-restricted-syntax -- table column minimum width constraint is intentional */}
                    <div className="flex items-center gap-2 min-w-[120px]">
                      <div className="progress-track flex-1">
                        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
                        <div
                          className="progress-fill"
                          style={{ "--progress": `${pct}%` } as React.CSSProperties}
                        />
                      </div>
                      <span className="text-muted-foreground text-xs shrink-0">
                        {worker.slots_busy}/{worker.slots_total}
                      </span>
                    </div>
                  </td>
                  <td className="py-3 pr-6 text-muted-foreground">
                    {relativeTime(worker.last_seen)}
                  </td>
                  <td className="py-3 pr-4">
                    {isLeader ? (
                      <Badge variant="default" className="gap-1">
                        <span aria-hidden>★</span> Leader
                      </Badge>
                    ) : (
                      <span className="text-muted-foreground text-xs">Worker</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* "Auto-refreshes every 15 seconds" was already said in the page
          subtitle above (page.tsx) — repeating it here just for a static
          fact read as noise. This line now only carries the one thing that
          actually changes: the live count, with a dot to say so. Sits
          outside the table's border box, not inside it. */}
      {/* pl-4 lines it up with the table's own left inset (Instance ID's
          pl-4) instead of sitting flush against the page edge, unaligned
          with everything above it. */}
      <p className="mt-4 flex items-center gap-1.5 pl-4 text-xs text-muted-foreground">
        <span aria-hidden className="h-1.5 w-1.5 shrink-0 animate-pulse rounded-full bg-success" />
        {data.workers.length} worker{data.workers.length !== 1 ? "s" : ""} active
      </p>
    </div>
  );
}
