"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ChevronRight, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { CohortGroupsPanel } from "@/app/(app)/cohort-groups/cohort-groups-panel";
import { EditCohortGroupPanel } from "@/app/(app)/cohort-groups/edit-cohort-group-panel";
import { BatchRow } from "@/app/(app)/cohort-groups/batch-row";
import { archiveCohortGroupAction, moveBatchToGroupAction } from "@/app/(app)/cohort-groups/actions";
import type { CohortGroup, CohortGroupNode, FlatCohortOption } from "@/lib/server/cohorts";
import type { Batch, OrgMemberSummary } from "@/lib/server/batches";

const DROP_HIGHLIGHT = ["ring-2", "ring-primary", "bg-primary/5"];

interface CohortTreeNodeProps {
  node: CohortGroupNode;
  depth: number;
  allGroups: CohortGroup[];
  mode: "manage" | "picker";
  selectedId?: string;
  onSelect?: (id: string) => void;
  batches?: Batch[];
  options?: FlatCohortOption[];
  orgMembers?: OrgMemberSummary[];
}

export function CohortTreeNode({ node, depth, allGroups, mode, selectedId, onSelect, batches = [], options = [], orgMembers = [] }: CohortTreeNodeProps) {
  const [open, setOpen] = useState(true);
  const [archiving, setArchiving] = useState(false);
  const router = useRouter();
  const rowRef = useRef<HTMLDivElement>(null);
  const ownBatches = batches.filter((b) => b.cohort_group_id === node.id);
  const hasChildren = node.children.length > 0;
  const hasContent = hasChildren || ownBatches.length > 0;

  function handleDragOver(e: React.DragEvent) {
    if (mode !== "manage") return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
  }

  function handleDragEnter(e: React.DragEvent) {
    if (mode !== "manage") return;
    e.preventDefault();
    rowRef.current?.classList.add(...DROP_HIGHLIGHT);
  }

  function handleDragLeave() {
    rowRef.current?.classList.remove(...DROP_HIGHLIGHT);
  }

  async function handleDrop(e: React.DragEvent) {
    if (mode !== "manage") return;
    e.preventDefault();
    rowRef.current?.classList.remove(...DROP_HIGHLIGHT);
    const batchId = e.dataTransfer.getData("text/plain");
    if (!batchId) return;
    const res = await moveBatchToGroupAction(batchId, node.id);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(`Moved into ${node.name}.`);
    router.refresh();
  }

  async function handleArchive() {
    if (node.batch_count > 0 || node.child_count > 0) {
      toast.error("Move or archive this group's batches and sub-groups first.");
      return;
    }
    setArchiving(true);
    const res = await archiveCohortGroupAction(node.id);
    setArchiving(false);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success("Group archived.");
    router.refresh();
  }

  return (
    <div>
      <div
        className={cn(
          "group flex items-center gap-1.5 rounded-md px-1.5 py-1.5 text-sm",
          mode === "picker" && selectedId === node.id ? "bg-primary/10 font-medium text-primary" : "text-foreground hover:bg-muted",
        )}
        ref={rowRef}
        // eslint-disable-next-line no-restricted-syntax -- tree indent depth is unbounded/dynamic, can't be a fixed Tailwind class
        style={{ paddingLeft: `${depth * 14 + 4}px` }}
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
        onDragOver={handleDragOver}
        onDrop={handleDrop}
      >
        <button
          aria-label={hasContent ? (open ? "Collapse" : "Expand") : undefined}
          className={cn("touch-target h-5 w-5 shrink-0 p-0 text-muted-foreground", !hasContent && "invisible")}
          type="button"
          onClick={() => setOpen((o) => !o)}
        >
          <ChevronRight aria-hidden className={cn("h-3.5 w-3.5 transition-transform duration-fast", open && "rotate-90")} />
        </button>

        <button
          className="flex min-w-0 flex-1 items-center gap-1.5 py-0.5 text-left"
          type="button"
          onClick={mode === "picker" ? () => onSelect?.(node.id) : undefined}
        >
          <span className="truncate">{node.name}</span>
          {node.level_label && <span className="shrink-0 text-xs text-muted-foreground">({node.level_label})</span>}
          <span className="shrink-0 text-xs text-muted-foreground">
            {node.batch_count} batch{node.batch_count !== 1 ? "es" : ""}
          </span>
        </button>

        {mode === "manage" && (
          <div className="hidden shrink-0 items-center gap-0.5 group-hover:flex">
            <EditCohortGroupPanel group={node} groups={allGroups} />
            <CohortGroupsPanel groups={allGroups} presetParentId={node.id} triggerLabel="Add sub-group" triggerSize="icon" triggerVariant="ghost" />
            <Button
              aria-label={`Archive ${node.name}`}
              disabled={archiving}
              size="icon"
              variant="ghost"
              onClick={handleArchive}
            >
              <Trash2 aria-hidden className="h-3.5 w-3.5 text-destructive" />
            </Button>
          </div>
        )}
      </div>

      {open && mode === "manage" && ownBatches.map((b) => (
        <BatchRow batch={b} depth={depth + 1} key={b.id} options={options} orgMembers={orgMembers} />
      ))}

      {open && hasChildren && (
        <div>
          {node.children.map((child) => (
            <CohortTreeNode
              allGroups={allGroups}
              batches={batches}
              depth={depth + 1}
              key={child.id}
              mode={mode}
              node={child}
              options={options}
              orgMembers={orgMembers}
              selectedId={selectedId}
              onSelect={onSelect}
            />
          ))}
        </div>
      )}
    </div>
  );
}
