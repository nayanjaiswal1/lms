"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ChevronRight, FileText, Plus, ChevronUp, ChevronDown } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { WikiPageTreeNode } from "@/lib/server/wiki";
import { movePageAction } from "@/lib/wiki/actions";

interface WikiTreeNodeProps {
  node: WikiPageTreeNode;
  siblings: WikiPageTreeNode[];
  index: number;
  path: string[]; // ancestor slugs, not including this node
  depth: number;
  spaceSlug: string;
  canManage: boolean;
  currentPath: string[];
  dragOverId: string | null;
  setDragOverId: (id: string | null) => void;
  onDrop: (dragId: string, parentId: string | null, orderIndex: number) => void;
  onRequestNewPage: (parentId: string) => void;
}

export function WikiTreeNode({
  node, siblings, index, path, depth, spaceSlug, canManage, currentPath,
  dragOverId, setDragOverId, onDrop, onRequestNewPage,
}: WikiTreeNodeProps) {
  const [open, setOpen] = useState(true);
  const router = useRouter();

  const fullPath = [...path, node.slug];
  const isActive = currentPath.length === fullPath.length && currentPath.every((s, i) => s === fullPath[i]);
  const hasChildren = node.children.length > 0;

  async function reorder(direction: "up" | "down") {
    const swapIndex = direction === "up" ? index - 1 : index + 1;
    const neighbor = siblings[swapIndex];
    if (!neighbor) return;
    const [a, b] = await Promise.all([
      movePageAction(node.id, { parent_id: node.parent_id ?? null, order_index: neighbor.order_index }),
      movePageAction(neighbor.id, { parent_id: neighbor.parent_id ?? null, order_index: node.order_index }),
    ]);
    if (!a.ok || !b.ok) {
      toast.error("Couldn't reorder that page.");
      return;
    }
    router.refresh();
  }

  return (
    <div>
      <div
        className={cn(
          "group flex items-center gap-1 rounded-md px-1.5 py-1 text-sm",
          isActive ? "bg-muted font-medium text-primary" : "text-foreground hover:bg-muted",
          dragOverId === node.id && "ring-1 ring-primary",
        )}
        draggable={canManage}
        // eslint-disable-next-line no-restricted-syntax -- tree indent depth is unbounded/dynamic, can't be a fixed Tailwind class
        style={{ paddingLeft: `${depth * 14 + 4}px` }}
        onDragOver={canManage ? (e) => { e.preventDefault(); setDragOverId(node.id); } : undefined}
        onDragStart={canManage ? (e) => e.dataTransfer.setData("text/plain", node.id) : undefined}
        onDrop={canManage ? (e) => {
          e.preventDefault();
          const dragId = e.dataTransfer.getData("text/plain");
          onDrop(dragId, node.id, node.children.length);
        } : undefined}
      >
        <button
          aria-label={hasChildren ? (open ? "Collapse" : "Expand") : undefined}
          className={cn("touch-target h-5 w-5 shrink-0 p-0 text-muted-foreground", !hasChildren && "invisible")}
          type="button"
          onClick={() => setOpen((o) => !o)}
        >
          <ChevronRight aria-hidden className={cn("h-3.5 w-3.5 transition-transform duration-fast", open && "rotate-90")} />
        </button>

        <Link className="flex min-w-0 flex-1 items-center gap-1.5 py-0.5" href={ROUTES.wikiPage(spaceSlug, ...fullPath)}>
          {node.emoji ? <span aria-hidden>{node.emoji}</span> : <FileText aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />}
          <span className="truncate">{node.title}</span>
          {node.status === "draft" && <span className="shrink-0 text-xs text-muted-foreground">(draft)</span>}
        </Link>

        {canManage && (
          <div className="hidden shrink-0 items-center gap-0.5 group-hover:flex">
            {index > 0 && (
              <button aria-label="Move up" className="touch-target h-5 w-5 p-0 text-muted-foreground hover:text-foreground" type="button" onClick={() => void reorder("up")}>
                <ChevronUp aria-hidden className="h-3.5 w-3.5" />
              </button>
            )}
            {index < siblings.length - 1 && (
              <button aria-label="Move down" className="touch-target h-5 w-5 p-0 text-muted-foreground hover:text-foreground" type="button" onClick={() => void reorder("down")}>
                <ChevronDown aria-hidden className="h-3.5 w-3.5" />
              </button>
            )}
            <button aria-label="New child page" className="touch-target h-5 w-5 p-0 text-muted-foreground hover:text-foreground" type="button" onClick={() => onRequestNewPage(node.id)}>
              <Plus aria-hidden className="h-3.5 w-3.5" />
            </button>
          </div>
        )}
      </div>

      {open && hasChildren && (
        <div>
          {node.children.map((child, i) => (
            <WikiTreeNode
              canManage={canManage}
              currentPath={currentPath}
              depth={depth + 1}
              dragOverId={dragOverId}
              index={i}
              key={child.id}
              node={child}
              path={fullPath}
              setDragOverId={setDragOverId}
              siblings={node.children}
              spaceSlug={spaceSlug}
              onDrop={onDrop}
              onRequestNewPage={onRequestNewPage}
            />
          ))}
        </div>
      )}
    </div>
  );
}
