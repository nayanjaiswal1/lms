"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useQueryState } from "nuqs";
import { Plus } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { WikiPageTreeNode, WikiTemplate } from "@/lib/server/wiki";
import { movePageAction } from "@/lib/wiki/actions";
import { WikiTreeNode } from "@/components/wiki/wiki-tree-node";
import { WikiNewPageDialog } from "@/components/wiki/wiki-new-page-dialog";

interface WikiSidebarTreeProps {
  spaceSlug: string;
  spaceId: string;
  tree: WikiPageTreeNode[];
  templates: WikiTemplate[];
  currentPath: string[];
  canManage: boolean;
}

export function WikiSidebarTree({ spaceSlug, spaceId, tree, templates, currentPath, canManage }: WikiSidebarTreeProps) {
  const router = useRouter();
  const [newPageParent, setNewPageParent] = useQueryState("newPage");
  const [dragOverId, setDragOverId] = useState<string | null>(null);

  async function handleDrop(dragId: string, parentId: string | null, orderIndex: number) {
    setDragOverId(null);
    if (dragId === parentId) return;
    const result = await movePageAction(dragId, { parent_id: parentId, order_index: orderIndex });
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't move that page.");
      return;
    }
    router.refresh();
  }

  return (
    <nav aria-label="Wiki pages" className="flex w-full flex-col gap-1 sm:w-64 sm:shrink-0">
      <div className="flex items-center justify-between px-1">
        <span className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Pages</span>
        {canManage && (
          <Button
            aria-label="New page"
            className="touch-target h-7 w-7 p-0"
            size="sm"
            variant="ghost"
            onClick={() => void setNewPageParent("root")}
          >
            <Plus aria-hidden className="h-4 w-4" />
          </Button>
        )}
      </div>

      <div
        className={cn("rounded-md", dragOverId === "root" && "bg-muted")}
        onDragOver={canManage ? (e) => { e.preventDefault(); setDragOverId("root"); } : undefined}
        onDrop={canManage ? (e) => {
          e.preventDefault();
          const id = e.dataTransfer.getData("text/plain");
          void handleDrop(id, null, tree.length);
        } : undefined}
      >
        {tree.length === 0 && <p className="px-2 py-4 text-sm text-muted-foreground">No pages yet.</p>}
        {tree.map((node, i) => (
          <WikiTreeNode
            canManage={canManage}
            currentPath={currentPath}
            depth={0}
            dragOverId={dragOverId}
            index={i}
            key={node.id}
            node={node}
            path={[]}
            setDragOverId={setDragOverId}
            siblings={tree}
            spaceSlug={spaceSlug}
            onDrop={handleDrop}
            onRequestNewPage={(parentId) => void setNewPageParent(parentId)}
          />
        ))}
      </div>

      {canManage && (
        <WikiNewPageDialog
          open={newPageParent !== null}
          parentId={newPageParent === "root" ? null : newPageParent}
          spaceId={spaceId}
          templates={templates}
          onClose={() => void setNewPageParent(null)}
        />
      )}
    </nav>
  );
}
