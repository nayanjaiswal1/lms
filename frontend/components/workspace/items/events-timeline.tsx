"use client";

import { useState } from "react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { apiFetch } from "@/lib/client/api";
import type { ItemEvent, Page } from "@/lib/workspace/types";

interface EventsTimelineProps {
  workspaceId: string;
  itemId: string;
  initialPage: Page<ItemEvent>;
}

const SOURCE_LABEL: Record<ItemEvent["source"], string> = { user: "", gitlab: "GitLab", system: "System" };

function describe(e: ItemEvent): string {
  if (e.kind === "create") return "created this item";
  if (e.kind === "field" && e.field) return `changed ${e.field} from "${e.from_value ?? "—"}" to "${e.to_value ?? "—"}"`;
  if (e.kind === "status") return `moved status from "${e.from_value ?? "—"}" to "${e.to_value ?? "—"}"`;
  if (e.kind === "assign") return `assigned ${e.to_value ?? ""}`;
  if (e.kind === "unassign") return `unassigned ${e.from_value ?? ""}`;
  if (e.kind === "link") return `linked ${e.to_value ?? ""}`;
  if (e.kind === "unlink") return `removed link ${e.from_value ?? ""}`;
  if (e.kind === "archive") return "archived this item";
  if (e.kind === "parent") return `moved under ${e.to_value ?? ""}`;
  if (e.kind === "severity") return `changed severity from "${e.from_value ?? "—"}" to "${e.to_value ?? "—"}"`;
  return e.kind.replace(/_/g, " ");
}

export function EventsTimeline({ workspaceId, itemId, initialPage }: EventsTimelineProps) {
  const [items, setItems] = useState(initialPage.items);
  const [nextCursor, setNextCursor] = useState(initialPage.next_cursor);
  const [loadingMore, setLoadingMore] = useState(false);

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    const params = new URLSearchParams({ cursor: nextCursor, limit: "20" });
    const page = await apiFetch<Page<ItemEvent>>(`/workspaces/${workspaceId}/items/${itemId}/events?${params.toString()}`);
    setLoadingMore(false);
    if (!page) {
      toast.error("Could not load more activity.");
      return;
    }
    setItems((prev) => [...prev, ...page.items]);
    setNextCursor(page.next_cursor);
  }

  if (items.length === 0) return <p className="text-sm text-muted-foreground">No activity yet.</p>;

  return (
    <div className="flex flex-col gap-4">
      <ul className="flex flex-col gap-3">
        {items.map((e) => (
          <li className="flex flex-col gap-0.5 border-b border-border pb-3 text-sm last:border-0" key={e.id}>
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="font-medium">{e.actor_name || "Someone"}</span>
              <span className="text-muted-foreground">{describe(e)}</span>
              {SOURCE_LABEL[e.source] && <Badge variant="outline">{SOURCE_LABEL[e.source]}</Badge>}
            </div>
            {e.reason && <p className="text-xs text-muted-foreground">Reason: {e.reason}</p>}
            <p className="text-xs text-muted-foreground">{new Date(e.created_at).toLocaleString()}</p>
          </li>
        ))}
      </ul>
      {nextCursor && (
        <div className="flex justify-center">
          <Button disabled={loadingMore} size="sm" variant="outline" onClick={loadMore}>
            {loadingMore ? "Loading…" : "Load more"}
          </Button>
        </div>
      )}
    </div>
  );
}
