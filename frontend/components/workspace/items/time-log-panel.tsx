"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Clock, Pencil, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { LogTimeDialog } from "@/components/workspace/items/log-time-dialog";
import { deleteTimeLogAction } from "@/lib/workspace/phase4-actions";
import type { Page, TimeLog } from "@/lib/workspace/types";

interface TimeLogPanelProps {
  workspaceId: string;
  itemId: string;
  initialPage: Page<TimeLog>;
}

function formatMinutes(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

export function TimeLogPanel({ workspaceId, itemId, initialPage }: TimeLogPanelProps) {
  const [logs, setLogs] = useState(initialPage.items);
  const [deleteTarget, setDeleteTarget] = useState<TimeLog | null>(null);
  const [pending, startTransition] = useTransition();

  function handleDelete() {
    if (!deleteTarget) return;
    const target = deleteTarget;
    startTransition(async () => {
      const result = await deleteTimeLogAction(workspaceId, target.id);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setLogs((prev) => prev.filter((l) => l.id !== target.id));
      toast.success("Time log deleted.");
      setDeleteTarget(null);
    });
  }

  const totalMinutes = logs.reduce((sum, l) => sum + l.minutes, 0);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          <Clock aria-hidden className="mr-1.5 inline h-4 w-4 align-text-bottom" />
          {formatMinutes(totalMinutes)} logged
        </p>
        <LogTimeDialog itemId={itemId} workspaceId={workspaceId} />
      </div>

      {logs.length === 0 ? (
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">No time logged on this item yet.</p>
        </div>
      ) : (
        <ResponsiveTable>
          <table className="w-full text-sm">
            <thead>
              <tr className="whitespace-nowrap text-left text-xs text-muted-foreground">
                <th className="px-3 py-2">Person</th>
                <th className="px-3 py-2">Date</th>
                <th className="px-3 py-2">Time</th>
                <th className="px-3 py-2">Note</th>
                <th className="px-3 py-2" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {logs.map((log) => (
                <tr className="whitespace-nowrap" key={log.id}>
                  <td className="px-3 py-2 font-medium">{log.user_name}</td>
                  <td className="px-3 py-2 text-muted-foreground">{log.logged_on}</td>
                  <td className="px-3 py-2">{formatMinutes(log.minutes)}</td>
                  <td className="min-w-0 max-w-xs truncate px-3 py-2 text-muted-foreground">{log.note ?? "—"}</td>
                  <td className="px-3 py-2 text-right">
                    {log.editable && (
                      <div className="flex justify-end gap-1">
                        <LogTimeDialog
                          editing={log}
                          itemId={itemId}
                          trigger={
                            <Button aria-label="Edit time log" size="icon" variant="ghost">
                              <Pencil aria-hidden className="h-4 w-4" />
                            </Button>
                          }
                          workspaceId={workspaceId}
                        />
                        <Button aria-label="Delete time log" size="icon" variant="ghost" onClick={() => setDeleteTarget(log)}>
                          <Trash2 aria-hidden className="h-4 w-4" />
                        </Button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </ResponsiveTable>
      )}

      <ConfirmDialog
        destructive
        confirmLabel="Delete"
        description="This time log will be permanently removed."
        open={deleteTarget !== null}
        pending={pending}
        title="Delete this time log?"
        onConfirm={handleDelete}
        onOpenChange={(open) => !open && setDeleteTarget(null)}
      />
    </div>
  );
}
