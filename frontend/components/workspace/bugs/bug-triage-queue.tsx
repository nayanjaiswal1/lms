"use client";

import { useState } from "react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { TriageDialog } from "@/components/workspace/bugs/triage-dialog";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import type { Member, WorkItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface BugTriageQueueProps {
  workspaceId: string;
  bugs: WorkItem[];
  members: Member[];
}

/** Untriaged (severity === null) bugs, oldest first — the "queue" the
 * contract asks for. Once triaged a bug always has a severity, so the row
 * simply drops out on the next server fetch (revalidatePath in
 * triageBugAction); we also remove it optimistically here. */
export function BugTriageQueue({ workspaceId, bugs, members }: BugTriageQueueProps) {
  const { atLeast, isLeadOf } = useProjectRole();
  const [rows, setRows] = useState(bugs);
  const [target, setTarget] = useState<WorkItem | null>(null);

  function canTriage(bug: WorkItem): boolean {
    return atLeast("manager") || (bug.track_id !== null && isLeadOf(bug.track_id));
  }

  if (rows.length === 0) {
    return <div className="empty-state"><p className="text-sm text-muted-foreground">No untriaged bugs.</p></div>;
  }

  return (
    <>
      <ResponsiveTable>
        <table className="w-full text-sm">
          <thead>
            <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
              <th className="px-3 py-2">Key</th>
              <th className="px-3 py-2">Title</th>
              <th className="px-3 py-2">Reported</th>
              <th className="px-3 py-2" />
            </tr>
          </thead>
          <tbody>
            {rows.map((bug) => (
              <tr className="whitespace-nowrap border-b border-border last:border-0" key={bug.id}>
                <td className="px-3 py-2 font-mono text-xs">{bug.key}</td>
                <td className="min-w-0 px-3 py-2 whitespace-normal">
                  <Link className="truncate hover:text-primary hover:underline" href={ROUTES.workspaceItem(workspaceId, bug.key)}>
                    {bug.title}
                  </Link>
                </td>
                <td className="px-3 py-2 text-muted-foreground">{new Date(bug.created_at).toLocaleDateString()}</td>
                <td className="px-3 py-2 text-right">
                  {canTriage(bug) && (
                    <Button size="sm" variant="outline" onClick={() => setTarget(bug)}>
                      Triage
                    </Button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </ResponsiveTable>

      {target && (
        <TriageDialog
          bug={target}
          members={members}
          open={target !== null}
          workspaceId={workspaceId}
          onOpenChange={(o) => !o && setTarget(null)}
          onTriaged={(bugId) => setRows((prev) => prev.filter((b) => b.id !== bugId))}
        />
      )}
    </>
  );
}
