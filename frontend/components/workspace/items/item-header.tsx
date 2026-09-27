"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Pencil } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ConflictDialog } from "@/components/workspace/items/conflict-dialog";
import { ItemDangerActions } from "@/components/workspace/items/item-danger-actions";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { updateWorkItemAction } from "@/lib/workspace/items-actions";
import {
  BUG_SEVERITY_VARIANT,
  ITEM_PRIORITY_VARIANT,
  ITEM_STATUS_LABEL,
  ITEM_STATUS_VARIANT,
  ITEM_TYPE_ICON,
  ITEM_TYPE_LABEL,
} from "@/lib/workspace/items-constants";
import type { ItemDetail, WorkItem } from "@/lib/workspace/types";

interface ItemHeaderProps {
  workspaceId: string;
  item: ItemDetail;
}

export function ItemHeader({ workspaceId, item }: ItemHeaderProps) {
  const router = useRouter();
  const { atLeast } = useProjectRole();
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(item.title);
  const [pending, startTransition] = useTransition();
  const [conflict, setConflict] = useState<WorkItem | null>(null);
  const TypeIcon = ITEM_TYPE_ICON[item.type];

  function saveTitle(version: number) {
    startTransition(async () => {
      const result = await updateWorkItemAction(workspaceId, item.id, { version, title });
      if (result.conflict) {
        setConflict(result.conflict);
        return;
      }
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Title updated.");
      setEditing(false);
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
          <TypeIcon aria-hidden className="h-4 w-4" />
          <span className="font-mono">{item.key}</span>
          <Badge variant="outline">{ITEM_TYPE_LABEL[item.type]}</Badge>
          <Badge variant={ITEM_STATUS_VARIANT[item.status]}>{ITEM_STATUS_LABEL[item.status]}</Badge>
          <Badge variant={ITEM_PRIORITY_VARIANT[item.priority]}>{item.priority}</Badge>
          {item.severity && <Badge variant={BUG_SEVERITY_VARIANT[item.severity]}>{item.severity}</Badge>}
          {item.doc_status && <Badge variant="outline">doc: {item.doc_status.replace("_", " ")}</Badge>}
        </div>
        <ItemDangerActions item={item} workspaceId={workspaceId} />
      </div>

      {editing ? (
        <div className="flex items-center gap-2">
          <Input className="text-lg font-semibold" value={title} onChange={(e) => setTitle(e.target.value)} />
          <Button disabled={pending} size="sm" onClick={() => saveTitle(item.version)}>
            {pending ? "Saving…" : "Save"}
          </Button>
          <Button disabled={pending} size="sm" variant="outline" onClick={() => { setTitle(item.title); setEditing(false); }}>
            Cancel
          </Button>
        </div>
      ) : (
        <div className="flex items-center gap-2">
          <h1 className="text-xl font-semibold">{item.title}</h1>
          {item.can_edit && (
            <Button aria-label="Edit title" size="icon" variant="ghost" onClick={() => setEditing(true)}>
              <Pencil aria-hidden className="h-4 w-4" />
            </Button>
          )}
        </div>
      )}

      <ConflictDialog
        canOverwrite={atLeast("manager")}
        current={conflict}
        fields={[{ label: "Title", yours: title, current: conflict?.title ?? "" }]}
        open={conflict !== null}
        pending={pending}
        onOpenChange={(o) => !o && setConflict(null)}
        onOverwrite={(version) => saveTitle(version)}
        onReload={() => { setConflict(null); router.refresh(); }}
      />
    </div>
  );
}
