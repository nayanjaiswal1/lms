import Link from "next/link";
import { AlertTriangle, Copy, ShieldAlert } from "lucide-react";
import type { ItemDetail } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface ItemBannersProps {
  workspaceId: string;
  item: ItemDetail;
}

/** Change-request / blocked / duplicate state callouts (04-frontend.md §4). */
export function ItemBanners({ workspaceId, item }: ItemBannersProps) {
  const blocker = item.links.find((l) => l.kind === "blocks" && l.direction === "incoming");
  const duplicateOf = item.links.find((l) => l.kind === "duplicates" && l.direction === "outgoing");

  return (
    <div className="flex flex-col gap-2">
      {item.spec_changed_at && (
        <div className="flex items-center gap-2 rounded-md border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-foreground">
          <AlertTriangle aria-hidden className="h-4 w-4 shrink-0" />
          The spec changed after this item was approved — check the feature doc before continuing.
        </div>
      )}
      {item.status === "blocked" && (
        <div className="flex items-center gap-2 rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
          <ShieldAlert aria-hidden className="h-4 w-4 shrink-0" />
          <span className="min-w-0 flex-1">
            Blocked{item.blocked_reason ? `: ${item.blocked_reason}` : "."}
            {blocker && (
              <>
                {" "}by{" "}
                <Link className="underline" href={ROUTES.workspaceItem(workspaceId, blocker.other.key)}>
                  {blocker.other.key}
                </Link>
              </>
            )}
          </span>
        </div>
      )}
      {duplicateOf && (
        <div className="flex items-center gap-2 rounded-md border border-border bg-muted px-3 py-2 text-sm text-muted-foreground">
          <Copy aria-hidden className="h-4 w-4 shrink-0" />
          Marked as a duplicate of{" "}
          <Link className="underline" href={ROUTES.workspaceItem(workspaceId, duplicateOf.other.key)}>
            {duplicateOf.other.key}
          </Link>
        </div>
      )}
    </div>
  );
}
