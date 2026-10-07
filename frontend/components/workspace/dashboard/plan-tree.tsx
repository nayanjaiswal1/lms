"use client";

import { Button } from "@/components/ui/button";
import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import ROUTES from "@/lib/routes";
import type { PlanTreeNode as PlanTreeNodeType } from "@/lib/workspace/types";

interface PlanTreeProps {
  workspaceId: string;
  nodes: PlanTreeNodeType[];
}

/** contract-phase4.md 04 §5: "plan tree (expand/collapse)" — epic -> feature
 * -> task/bug/subtask, each node showing roll-up progress and its owner. */
export function PlanTree({ workspaceId, nodes }: PlanTreeProps) {
  if (nodes.length === 0) {
    return (
      <div className="empty-state py-8">
        <p className="text-sm text-muted-foreground">No work items yet.</p>
      </div>
    );
  }
  return (
    <ul className="flex flex-col gap-1">
      {nodes.map((node) => (
        <PlanTreeRow depth={0} key={node.item.id} node={node} workspaceId={workspaceId} />
      ))}
    </ul>
  );
}

function PlanTreeRow({ node, depth, workspaceId }: { node: PlanTreeNodeType; depth: number; workspaceId: string }) {
  const [expanded, setExpanded] = useState(depth < 1);
  const hasChildren = node.children.length > 0;

  return (
    <li>
      {/* eslint-disable-next-line no-restricted-syntax -- dynamic tree-depth indent requires inline style */}
      <div className="flex items-center gap-1.5 rounded-md py-1 hover:bg-muted" style={{ paddingLeft: depth * 20 }}>
        {hasChildren ? (
          <Button aria-label={expanded ? "Collapse" : "Expand"}
            className="text-muted-foreground"
            type="button"
            variant="unstyled"
            onClick={() => setExpanded((e) => !e)}
          >
            {expanded ? <ChevronDown aria-hidden className="h-4 w-4" /> : <ChevronRight aria-hidden className="h-4 w-4" />}
          </Button>
        ) : (
          <span className="w-4" />
        )}
        <Link className="min-w-0 flex-1 truncate text-sm hover:underline" href={ROUTES.workspaceItem(workspaceId, node.item.key)}>
          <span className="text-muted-foreground">{node.item.key}</span> {node.item.title}
        </Link>
        {node.at_risk && <Badge className="badge-warning shrink-0" variant="outline">At risk</Badge>}
        {node.owner && <span className="shrink-0 text-xs text-muted-foreground">{node.owner.name}</span>}
        <span className="w-10 shrink-0 text-right text-xs text-muted-foreground">{node.progress_pct.toFixed(0)}%</span>
      </div>
      {hasChildren && expanded && (
        <ul className="flex flex-col gap-1">
          {node.children.map((child) => (
            <PlanTreeRow depth={depth + 1} key={child.item.id} node={child} workspaceId={workspaceId} />
          ))}
        </ul>
      )}
    </li>
  );
}
