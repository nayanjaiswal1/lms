"use client";

import { useTransition } from "react";
import { Check, Circle, ExternalLink, RotateCcw, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { deleteSheetItemAction, updateProgressAction } from "@/lib/sheets/actions";
import type { ProgressStatus, SheetItem } from "@/lib/server/sheets";

interface SheetTableRowProps {
  sheetId: string;
  item: SheetItem;
  index: number;
  isOwner: boolean;
}

const NEXT_STATUS: Record<ProgressStatus, ProgressStatus> = {
  todo: "done",
  done: "revisit",
  revisit: "todo",
};

const STATUS_ICON: Record<ProgressStatus, typeof Check> = {
  todo: Circle,
  done: Check,
  revisit: RotateCcw,
};

const STATUS_LABEL: Record<ProgressStatus, string> = {
  todo: "Mark as solved",
  done: "Mark for revision",
  revisit: "Mark as unsolved",
};

const STATUS_CLASS: Record<ProgressStatus, string> = {
  todo: "text-muted-foreground border-border",
  done: "text-success border-success bg-success/10",
  revisit: "text-warning-foreground border-warning bg-warning/10",
};

const DIFFICULTY_CLASS: Record<string, string> = {
  easy: "bg-success/10 text-success border-success/20",
  medium: "bg-warning/10 text-warning-foreground border-warning/20",
  hard: "bg-destructive/10 text-destructive border-destructive/20",
};

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function SheetTableRow({ sheetId, item, index, isOwner }: SheetTableRowProps) {
  const [isPending, startTransition] = useTransition();
  const StatusIcon = STATUS_ICON[item.status];

  function cycleStatus() {
    const next = NEXT_STATUS[item.status];
    startTransition(async () => {
      await updateProgressAction(item.topic_tag, next);
    });
  }

  function remove() {
    startTransition(async () => {
      await deleteSheetItemAction(sheetId, item.id);
    });
  }

  return (
    <li
      className={cn(
        "flex items-center gap-3 px-3 py-3 rounded-md",
        index % 2 === 1 && "bg-muted/40",
      )}
    >
      <button
        aria-label={STATUS_LABEL[item.status]}
        className={cn(
          "touch-target flex items-center justify-center rounded-full border shrink-0",
          STATUS_CLASS[item.status],
        )}
        disabled={isPending}
        type="button"
        onClick={cycleStatus}
      >
        <StatusIcon aria-hidden className="h-4 w-4" />
      </button>

      <div className="min-w-0 flex-1">
        {item.external_url ? (
          <a
            className="inline-flex items-center gap-1 text-sm font-medium text-foreground hover:text-primary truncate"
            href={item.external_url}
            rel="noopener noreferrer"
            target="_blank"
          >
            {item.title}
            <ExternalLink aria-hidden className="h-3 w-3 shrink-0" />
          </a>
        ) : (
          <p className="text-sm font-medium text-foreground truncate">{item.title}</p>
        )}
        {item.category && <p className="text-xs text-muted-foreground truncate">{item.category}</p>}
      </div>

      <div className="flex items-center gap-2 shrink-0">
        {item.difficulty && (
          <Badge className={DIFFICULTY_CLASS[item.difficulty]} variant="outline">
            {item.difficulty}
          </Badge>
        )}
        {item.revision_at && (
          <span className="text-xs text-muted-foreground tabular-nums hidden sm:inline">
            Revise {formatDate(item.revision_at)}
          </span>
        )}
        {isOwner && (
          <button
            aria-label={`Delete ${item.title}`}
            className="touch-target text-muted-foreground hover:text-destructive"
            disabled={isPending}
            type="button"
            onClick={remove}
          >
            <Trash2 aria-hidden className="h-4 w-4" />
          </button>
        )}
      </div>
    </li>
  );
}
