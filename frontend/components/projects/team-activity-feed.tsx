"use client";

import { parseAsString, useQueryState } from "nuqs";
import { ExternalLink, GitCommitHorizontal } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import type { TeamActivityView } from "@/lib/projects/types";

const MR_STATE_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  opened: "default",
  merged: "secondary",
  closed: "destructive",
  locked: "outline",
};

// GitLab's own pipeline status enum (not a MindForge-owned fixed set — see
// TeamActivityPipeline's own doc comment in lib/projects/types.ts), so this
// only maps the common terminal/active states; anything else falls back to
// "outline" rather than growing this map to track GitLab's full CI vocabulary.
export const PIPELINE_STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  success: "default",
  running: "secondary",
  pending: "outline",
  failed: "destructive",
  canceled: "outline",
  skipped: "outline",
};

interface TeamActivityFeedProps {
  teamId: string;
  teamName: string;
  activity: TeamActivityView;
}

export function TeamActivityFeed({ teamId, teamName, activity }: TeamActivityFeedProps) {
  const [openTeamId, setOpenTeamId] = useQueryState("activity", parseAsString);
  const isOpen = openTeamId === teamId;
  const isEmpty = activity.commits.length === 0 && activity.merge_requests.length === 0 && !activity.pipeline;

  return (
    <Sheet open={isOpen} onOpenChange={(next) => void setOpenTeamId(next ? teamId : null)}>
      <SheetTrigger asChild>
        <Button size="sm" variant="outline">
          <GitCommitHorizontal aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          Activity
        </Button>
      </SheetTrigger>
      <SheetContent className="modal-responsive flex flex-col gap-4">
        <SheetHeader>
          <SheetTitle>{teamName} — activity</SheetTitle>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto">
          {isEmpty ? (
            <div className="empty-state">
              <GitCommitHorizontal aria-hidden className="empty-state-icon" />
              <p className="font-medium text-muted-foreground">No activity yet.</p>
              <p className="text-sm text-muted-foreground">
                Commits, merge requests, and pipeline runs appear here once GitLab starts sending webhook events for
                this repo.
              </p>
            </div>
          ) : (
            <>
              {activity.pipeline && (
                <section className="flex flex-col gap-2">
                  <h3 className="text-sm font-semibold">Latest pipeline</h3>
                  <div className="flex items-center gap-2">
                    <Badge variant={PIPELINE_STATUS_VARIANT[activity.pipeline.status] ?? "outline"}>
                      {activity.pipeline.status}
                    </Badge>
                    {activity.pipeline.web_url && (
                      <a
                        className="inline-flex items-center gap-1 text-xs hover:underline"
                        href={activity.pipeline.web_url}
                        rel="noreferrer"
                        target="_blank"
                      >
                        View <ExternalLink aria-hidden className="h-3 w-3" />
                      </a>
                    )}
                  </div>
                </section>
              )}

              {activity.merge_requests.length > 0 && (
                <section className="flex flex-col gap-2">
                  <h3 className="text-sm font-semibold">Merge requests</h3>
                  <ul className="divide-y divide-border rounded-md border border-border">
                    {activity.merge_requests.map((mr, i) => (
                      <li className="flex items-center gap-3 px-3 py-2.5 text-sm" key={`${mr.title}-${i}`}>
                        <span className="min-w-0 flex-1 truncate">{mr.title}</span>
                        <span className="shrink-0 text-xs text-muted-foreground">
                          {mr.approvals_count} approval{mr.approvals_count === 1 ? "" : "s"}
                        </span>
                        <Badge variant={MR_STATE_VARIANT[mr.state] ?? "outline"}>{mr.state}</Badge>
                        {mr.web_url && (
                          <a aria-label={`Open ${mr.title} in GitLab`} href={mr.web_url} rel="noreferrer" target="_blank">
                            <ExternalLink aria-hidden className="h-3.5 w-3.5" />
                          </a>
                        )}
                      </li>
                    ))}
                  </ul>
                </section>
              )}

              {activity.commits.length > 0 && (
                <section className="flex flex-col gap-2">
                  <h3 className="text-sm font-semibold">Recent commits</h3>
                  <ul className="divide-y divide-border rounded-md border border-border">
                    {activity.commits.map((c) => (
                      <li className="flex flex-col gap-0.5 px-3 py-2.5 text-sm" key={c.sha}>
                        <span className="flex items-center gap-2">
                          <code className="text-xs text-muted-foreground">{c.sha.slice(0, 8)}</code>
                          <span className="truncate">{c.message ?? "(no message)"}</span>
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {c.author_name ?? "Unknown"}
                          {c.committed_at && ` · ${new Date(c.committed_at).toLocaleString()}`}
                        </span>
                      </li>
                    ))}
                  </ul>
                </section>
              )}
            </>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
