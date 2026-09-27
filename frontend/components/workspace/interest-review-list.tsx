"use client";

import * as React from "react";
import { toast } from "sonner";
import { Copy } from "lucide-react";
import { parseAsStringEnum, useQueryState } from "nuqs";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { AcceptInterestDialog } from "@/components/workspace/accept-interest-dialog";
import { rejectInterestAction } from "@/lib/workspace/actions";
import { apiFetch } from "@/lib/client/api";
import { INTEREST_STATUS_LABEL, INTEREST_STATUS_VARIANT } from "@/lib/workspace/roles";
import type { Interest, InterestStatus, Page } from "@/lib/workspace/types";

const STATUS_VALUES = ["new", "accepted", "rejected", "invite_expired", "joined"] as const;

// Extracted so the component itself stays within the 2-useState budget
// (frontend/CLAUDE.md "Component Constraints") — this owns the paginated
// item list, the component below owns only the two dialog/pending states.
function useInterestFeed(workspaceId: string, status: InterestStatus, initialPage: Page<Interest>) {
  const [items, setItems] = React.useState(initialPage.items);
  const [nextCursor, setNextCursor] = React.useState(initialPage.next_cursor);
  const [loadingMore, setLoadingMore] = React.useState(false);

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    const params = new URLSearchParams({ status, cursor: nextCursor, limit: "20" });
    const page = await apiFetch<Page<Interest>>(`/workspaces/${workspaceId}/interests?${params.toString()}`);
    setLoadingMore(false);
    if (!page) {
      toast.error("Could not load more interests.");
      return;
    }
    setItems((prev) => [...prev, ...page.items]);
    setNextCursor(page.next_cursor);
  }

  function removeItem(id: string) {
    setItems((prev) => prev.filter((i) => i.id !== id));
  }

  return { items, nextCursor, loadingMore, loadMore, removeItem };
}

interface InterestReviewListProps {
  workspaceId: string;
  status: InterestStatus;
  initialPage: Page<Interest>;
  seatsUsed: number;
  teamSizeMax: number;
  /** Present only when the caller can see the share link (owner/manager). */
  joinUrl?: string;
}

export function InterestReviewList({ workspaceId, status, initialPage, seatsUsed, teamSizeMax, joinUrl }: InterestReviewListProps) {
  const [, setStatus] = useQueryState("status", parseAsStringEnum<InterestStatus>([...STATUS_VALUES]).withDefault("new"));
  const { items, nextCursor, loadingMore, loadMore, removeItem } = useInterestFeed(workspaceId, status, initialPage);
  const [pendingId, setPendingId] = React.useState<string | null>(null);
  const [rejectTarget, setRejectTarget] = React.useState<Interest | null>(null);

  async function handleReject(interest: Interest) {
    setPendingId(interest.id);
    const result = await rejectInterestAction(workspaceId, interest.id);
    setPendingId(null);
    setRejectTarget(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Interest rejected.");
    removeItem(interest.id);
  }

  async function copyJoinUrl() {
    if (!joinUrl) return;
    await navigator.clipboard.writeText(joinUrl);
    toast.success("Share link copied.");
  }

  return (
    <Tabs value={status} onValueChange={(next) => void setStatus(next as InterestStatus)}>
      <TabsList>
        {STATUS_VALUES.map((value) => (
          <TabsTrigger key={value} value={value}>
            {INTEREST_STATUS_LABEL[value]}
          </TabsTrigger>
        ))}
      </TabsList>

      <div className="mt-4">
        {items.length === 0 ? (
          <div className="empty-state">
            <p className="font-medium text-muted-foreground">
              {status === "new" ? "No new interest yet." : `No ${INTEREST_STATUS_LABEL[status].toLowerCase()} interest.`}
            </p>
            {status === "new" && joinUrl && (
              <Button className="gap-2" size="sm" variant="outline" onClick={copyJoinUrl}>
                <Copy aria-hidden className="h-4 w-4" />
                Copy share link
              </Button>
            )}
          </div>
        ) : (
          <ul className="divide-y divide-border rounded-md border border-border">
            {items.map((interest) => (
              <li className="flex flex-col gap-2 px-4 py-3" key={interest.id}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate font-medium">{interest.name}</p>
                    <p className="truncate text-xs text-muted-foreground">{interest.email}</p>
                  </div>
                  <div className="flex items-center gap-1.5">
                    {interest.ai_score !== null && (
                      <Badge className="text-ai" variant="outline">
                        {Math.round(interest.ai_score)}/100
                      </Badge>
                    )}
                    <Badge variant={INTEREST_STATUS_VARIANT[interest.status]}>{INTEREST_STATUS_LABEL[interest.status]}</Badge>
                  </div>
                </div>
                {interest.skills.length > 0 && (
                  <div className="flex flex-wrap gap-1">
                    {interest.skills.map((skill) => (
                      <Badge key={skill} variant="secondary">{skill}</Badge>
                    ))}
                  </div>
                )}
                {interest.message && <p className="text-sm text-muted-foreground">{interest.message}</p>}
                {interest.portfolio_url && (
                  <a
                    className="text-sm text-primary hover:underline"
                    href={interest.portfolio_url}
                    rel="noopener noreferrer nofollow ugc"
                    target="_blank"
                  >
                    Portfolio
                  </a>
                )}
                {interest.ai_rationale && <p className="ai-surface rounded-md p-2 text-xs">{interest.ai_rationale}</p>}
                {interest.status === "new" && (
                  <div className="flex flex-wrap gap-2">
                    <AcceptInterestDialog
                      interest={interest}
                      seatsUsed={seatsUsed}
                      teamSizeMax={teamSizeMax}
                      workspaceId={workspaceId}
                      onAccepted={() => removeItem(interest.id)}
                    />
                    <Button
                      disabled={pendingId === interest.id}
                      size="sm"
                      variant="outline"
                      onClick={() => setRejectTarget(interest)}
                    >
                      Reject
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}

        {nextCursor && (
          <div className="mt-4 flex justify-center">
            <Button disabled={loadingMore} variant="outline" onClick={loadMore}>
              {loadingMore ? "Loading…" : "Load more"}
            </Button>
          </div>
        )}
      </div>

      <ConfirmDialog
        destructive
        confirmLabel="Reject"
        description={rejectTarget ? `${rejectTarget.name} will not be invited. This can't be undone.` : ""}
        open={rejectTarget !== null}
        pending={rejectTarget !== null && pendingId === rejectTarget.id}
        title={rejectTarget ? `Reject ${rejectTarget.name}'s interest?` : "Reject interest?"}
        onConfirm={() => rejectTarget && handleReject(rejectTarget)}
        onOpenChange={(open) => !open && setRejectTarget(null)}
      />
    </Tabs>
  );
}
