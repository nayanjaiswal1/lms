"use client";

import { useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Undo2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { revertMcpActionAction } from "@/app/(app)/settings/integrations/activity/actions";

export interface McpActionLogEntry {
  id: string;
  tool_name: string;
  args: unknown;
  target_type?: string;
  target_id?: string;
  before_state?: unknown;
  after_state?: unknown;
  revertible: boolean;
  reverted_at?: string | null;
  created_at: string;
}

export interface McpActionLogPage {
  entries: McpActionLogEntry[];
  next_cursor?: string;
}

function toolLabel(toolName: string): string {
  return toolName.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function toolBadgeVariant(toolName: string): "default" | "secondary" | "destructive" | "outline" {
  if (toolName.startsWith("create") || toolName.startsWith("add")) return "default";
  if (toolName.startsWith("delete")) return "destructive";
  if (toolName.startsWith("update") || toolName.startsWith("save") || toolName.startsWith("log")) return "secondary";
  return "outline";
}

function formatRelativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function summarizeArgs(args: unknown): string {
  if (!args || typeof args !== "object") return "";
  return Object.entries(args as Record<string, unknown>)
    .map(([key, value]) => {
      const str = typeof value === "string" ? value : JSON.stringify(value);
      const truncated = str.length > 60 ? `${str.slice(0, 60)}…` : str;
      return `${key}: ${truncated}`;
    })
    .join("  ·  ");
}

export function McpActionLog({ page }: { page: McpActionLogPage }) {
  const [revertTarget, setRevertTarget] = useState<McpActionLogEntry | null>(null);

  async function handleRevert() {
    if (!revertTarget) return;
    const target = revertTarget;
    setRevertTarget(null);
    const result = await revertMcpActionAction(target.id);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`Reverted "${toolLabel(target.tool_name)}".`);
  }

  return (
    <section aria-labelledby="mcp-activity-heading" className="card-base p-6">
      <div className="mb-6">
        <h2 className="text-lg font-semibold text-foreground" id="mcp-activity-heading">
          Activity Log
        </h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Every action your connected AI has taken on your account. Revert anything you didn&apos;t mean to happen.
        </p>
      </div>

      {page.entries.length === 0 ? (
        <div className="empty-state py-12">
          <p className="text-sm text-muted-foreground">No AI activity recorded yet.</p>
        </div>
      ) : (
        <div>
          {page.entries.map((entry) => {
            const disabledReason = entry.reverted_at
              ? "Already reverted"
              : !entry.revertible
                ? "This action can't be reverted"
                : null;
            const argsSummary = summarizeArgs(entry.args);
            const showDiff = Boolean(entry.before_state) && Boolean(entry.after_state);

            return (
              <div className="flex flex-col gap-3 border-b border-border py-4 last:border-0" key={entry.id}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge variant={toolBadgeVariant(entry.tool_name)}>{toolLabel(entry.tool_name)}</Badge>
                    {entry.target_type && (
                      <span className="text-xs text-muted-foreground">
                        {entry.target_type}
                        {entry.target_id && (
                          <span className="ml-1 font-mono text-foreground">#{entry.target_id.slice(0, 8)}</span>
                        )}
                      </span>
                    )}
                    <span className="text-xs text-muted-foreground">{formatRelativeTime(entry.created_at)}</span>
                    {entry.reverted_at && <Badge variant="outline">Reverted</Badge>}
                  </div>

                  {disabledReason ? (
                    <TooltipProvider>
                      <Tooltip>
                        <TooltipTrigger asChild>
                          <span>
                            <Button disabled size="sm" variant="outline">
                              <Undo2 aria-hidden className="mr-1.5 h-3.5 w-3.5" />
                              Revert
                            </Button>
                          </span>
                        </TooltipTrigger>
                        <TooltipContent>{disabledReason}</TooltipContent>
                      </Tooltip>
                    </TooltipProvider>
                  ) : (
                    <Button size="sm" variant="outline" onClick={() => setRevertTarget(entry)}>
                      <Undo2 aria-hidden className="mr-1.5 h-3.5 w-3.5" />
                      Revert
                    </Button>
                  )}
                </div>

                {argsSummary && <p className="truncate text-xs text-muted-foreground">{argsSummary}</p>}

                {showDiff && (
                  <div className="stack-md">
                    <div className="min-w-0 flex-1">
                      <p className="mb-1 text-xs font-semibold text-muted-foreground">Before</p>
                      <pre className="max-h-48 overflow-auto rounded-md bg-muted p-2 text-xs whitespace-pre-wrap break-words">
                        {JSON.stringify(entry.before_state, null, 2)}
                      </pre>
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="mb-1 text-xs font-semibold text-muted-foreground">After</p>
                      <pre className="max-h-48 overflow-auto rounded-md bg-muted p-2 text-xs whitespace-pre-wrap break-words">
                        {JSON.stringify(entry.after_state, null, 2)}
                      </pre>
                    </div>
                  </div>
                )}
              </div>
            );
          })}

          {page.next_cursor && (
            <div className="flex justify-center pt-4">
              <Button asChild variant="secondary">
                <Link href={`?cursor=${encodeURIComponent(page.next_cursor)}`}>Load more</Link>
              </Button>
            </div>
          )}
        </div>
      )}

      <AlertDialog open={revertTarget !== null} onOpenChange={(open) => !open && setRevertTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Revert &quot;{revertTarget && toolLabel(revertTarget.tool_name)}&quot;?</AlertDialogTitle>
            <AlertDialogDescription>
              This restores what existed before your AI made this change. It can&apos;t be undone from here.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleRevert}>Revert</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}
