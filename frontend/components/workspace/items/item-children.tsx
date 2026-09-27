"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { CreateItemDialog } from "@/components/workspace/items/create-item-dialog";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { ITEM_STATUS_LABEL, ITEM_STATUS_VARIANT, ITEM_TYPE_LABEL } from "@/lib/workspace/items-constants";
import { ITEM_CHILD_TYPES, type ItemDetail, type Track } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface ItemChildrenProps {
  workspaceId: string;
  item: ItemDetail;
  tracks: Track[];
}

export function ItemChildren({ workspaceId, item, tracks }: ItemChildrenProps) {
  const { atLeast } = useProjectRole();
  // epic/feature creation is manager+ only from this shortcut (the general
  // "New item" flow on board/list still lets a track lead create a feature
  // with their own track_id, per contract-phase2.md's "manager+ or lead of
  // track_id" rule — approximated here to keep this picker simple).
  const childTypes = ITEM_CHILD_TYPES[item.type].filter((t) => (t === "epic" || t === "feature" ? atLeast("manager") : true));

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-medium text-muted-foreground">Children</h2>
        {childTypes.length > 0 && (
          <CreateItemDialog
            allowedTypes={childTypes}
            defaultParentId={item.id}
            tracks={tracks}
            triggerLabel="Add child"
            workspaceId={workspaceId}
          />
        )}
      </div>

      {item.children.length === 0 && <p className="text-sm text-muted-foreground">No children yet.</p>}

      <ul className="flex flex-col gap-1.5">
        {item.children.map((c) => (
          <li className="flex items-center justify-between gap-2 text-sm" key={c.id}>
            <Link className="min-w-0 truncate hover:text-primary hover:underline" href={ROUTES.workspaceItem(workspaceId, c.key)}>
              <span className="font-mono text-xs text-muted-foreground">{c.key}</span> {c.title}
            </Link>
            <div className="flex shrink-0 items-center gap-1.5">
              <Badge variant="outline">{ITEM_TYPE_LABEL[c.type]}</Badge>
              <Badge variant={ITEM_STATUS_VARIANT[c.status]}>{ITEM_STATUS_LABEL[c.status]}</Badge>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
