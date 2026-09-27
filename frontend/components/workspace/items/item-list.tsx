"use client";

import { useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { apiFetch } from "@/lib/client/api";
import { ITEM_PRIORITY_VARIANT, ITEM_STATUS_LABEL, ITEM_STATUS_VARIANT, ITEM_TYPE_LABEL } from "@/lib/workspace/items-constants";
import type { Page, WorkItem } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface ItemListProps {
  workspaceId: string;
  initialPage: Page<WorkItem>;
}

export function ItemList({ workspaceId, initialPage }: ItemListProps) {
  const searchParams = useSearchParams();
  const [items, setItems] = useState(initialPage.items);
  const [nextCursor, setNextCursor] = useState(initialPage.next_cursor);
  const [loadingMore, setLoadingMore] = useState(false);

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    const params = new URLSearchParams(searchParams.toString());
    params.set("cursor", nextCursor);
    params.set("limit", "30");
    const page = await apiFetch<Page<WorkItem>>(`/workspaces/${workspaceId}/items?${params.toString()}`);
    setLoadingMore(false);
    if (!page) {
      toast.error("Could not load more items.");
      return;
    }
    setItems((prev) => [...prev, ...page.items]);
    setNextCursor(page.next_cursor);
  }

  if (items.length === 0) {
    return <div className="empty-state"><p className="text-sm text-muted-foreground">No items match these filters.</p></div>;
  }

  return (
    <div className="flex flex-col gap-4">
      <ResponsiveTable>
        <table className="w-full text-sm">
          <thead>
            <tr className="whitespace-nowrap border-b border-border text-left text-xs text-muted-foreground">
              <th className="px-3 py-2">Key</th>
              <th className="px-3 py-2">Type</th>
              <th className="px-3 py-2">Title</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2">Priority</th>
              <th className="px-3 py-2">Owner</th>
              <th className="px-3 py-2">Updated</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => {
              const owner = item.assignees.find((a) => a.role === "owner");
              return (
                <tr className="whitespace-nowrap border-b border-border last:border-0" key={item.id}>
                  <td className="px-3 py-2 font-mono text-xs">{item.key}</td>
                  <td className="px-3 py-2">{ITEM_TYPE_LABEL[item.type]}</td>
                  <td className="min-w-0 px-3 py-2 whitespace-normal">
                    <Link className="truncate hover:text-primary hover:underline" href={ROUTES.workspaceItem(workspaceId, item.key)}>
                      {item.title}
                    </Link>
                  </td>
                  <td className="px-3 py-2"><Badge variant={ITEM_STATUS_VARIANT[item.status]}>{ITEM_STATUS_LABEL[item.status]}</Badge></td>
                  <td className="px-3 py-2"><Badge variant={ITEM_PRIORITY_VARIANT[item.priority]}>{item.priority}</Badge></td>
                  <td className="min-w-0 px-3 py-2 truncate">{owner?.name ?? "—"}</td>
                  <td className="px-3 py-2 text-muted-foreground">{new Date(item.updated_at).toLocaleDateString()}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </ResponsiveTable>

      {nextCursor && (
        <div className="flex justify-center">
          <Button disabled={loadingMore} variant="outline" onClick={loadMore}>
            {loadingMore ? "Loading…" : "Load more"}
          </Button>
        </div>
      )}
    </div>
  );
}
