"use client";

import { useTransition } from "react";
import { Check, Circle, ExternalLink, RotateCcw, Star, Trash2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { RevisionDateBadge } from "@/components/sheets/revision-date-badge";
import { cn } from "@/lib/utils";
import {
  deleteSheetItemAction,
  markReviewedAction,
  updateProgressAction,
  updateProgressStarredAction,
} from "@/lib/sheets/actions";
import type { ProgressStatus, SheetItem } from "@/lib/server/sheets";

interface SheetTableRowProps {
  sheetId: string;
  item: SheetItem;
  index: number;
  isOwner: boolean;
  isEditMode: boolean;
  isActive?: boolean;
  onSelect?: (itemId: string) => void;
}

export function sheetRowId(itemId: string): string {
  return `sheet-row-${itemId}`;
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
  revisit: "text-warning border-warning bg-warning/10",
};

const DIFFICULTY_CLASS: Record<string, string> = {
  easy: "bg-success/10 text-success border-success/20",
  medium: "bg-warning/10 text-warning border-warning/20",
  hard: "bg-destructive/10 text-destructive border-destructive/20",
};

export function SheetTableRow({ sheetId, item, index, isOwner, isEditMode, isActive, onSelect }: SheetTableRowProps) {
  const [isPending, startTransition] = useTransition();
  const StatusIcon = STATUS_ICON[item.status];
  const isDue = item.status === "done" && !!item.revision_at && new Date(item.revision_at) <= new Date();

  function cycleStatus(e: React.MouseEvent) {
    e.stopPropagation();
    const next = NEXT_STATUS[item.status];
    startTransition(async () => {
      await updateProgressAction(item.topic_tag, next, sheetId);
    });
  }

  function goNext() {
    startTransition(async () => {
      await markReviewedAction(item.topic_tag, sheetId);
    });
  }

  function remove(e: React.MouseEvent) {
    e.stopPropagation();
    startTransition(async () => {
      await deleteSheetItemAction(sheetId, item.id);
    });
  }

  function toggleStarred(e: React.MouseEvent) {
    e.stopPropagation();
    startTransition(async () => {
      await updateProgressStarredAction(item.topic_tag, !item.is_starred);
    });
  }

  return (
    // eslint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- role/tabIndex/onKeyDown below already make this a real keyboard-operable button; jsx-a11y can't resolve the conditional `role` expression statically.
    <li
      aria-current={onSelect && isActive ? "true" : undefined}
      className={cn(
        "flex items-center gap-3 px-3 py-3 rounded-md",
        index % 2 === 1 && "bg-muted/40",
        onSelect && "cursor-pointer",
        isActive && "ring-1 ring-inset ring-primary bg-primary/5",
      )}
      id={onSelect ? sheetRowId(item.id) : undefined}
      role={onSelect ? "button" : undefined}
      tabIndex={onSelect ? 0 : undefined}
      onClick={onSelect ? () => onSelect(item.id) : undefined}
      onKeyDown={
        onSelect
          ? (e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onSelect(item.id);
              }
            }
          : undefined
      }
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

      <button
        aria-label={item.is_starred ? "Unstar" : "Star"}
        aria-pressed={item.is_starred}
        className={cn(
          "touch-target shrink-0 text-muted-foreground hover:text-primary",
          item.is_starred && "text-primary",
        )}
        disabled={isPending}
        type="button"
        onClick={toggleStarred}
      >
        <Star aria-hidden className={cn("h-4 w-4", item.is_starred && "fill-current")} />
      </button>

      <div className="min-w-0 flex-1">
        {item.external_url ? (
          <a
            className="flex w-full min-w-0 items-center gap-1 text-sm font-medium text-foreground hover:text-primary"
            href={item.external_url}
            rel="noopener noreferrer"
            target="_blank"
            onClick={(e) => e.stopPropagation()}
          >
            <span className="truncate">{item.title}</span>
            <ExternalLink aria-hidden className="h-3 w-3 shrink-0" />
          </a>
        ) : (
          <p className="text-sm font-medium text-foreground truncate">{item.title}</p>
        )}
        <div className="flex items-center gap-2">
          {item.category && <p className="truncate text-xs text-muted-foreground">{item.category}</p>}
          <div className="ml-auto flex shrink-0 items-center gap-2">
            {item.difficulty && (
              <Badge className={DIFFICULTY_CLASS[item.difficulty]} variant="outline">
                {item.difficulty}
              </Badge>
            )}
            {item.revision_at && (
              <RevisionDateBadge
                disabled={isPending}
                isDue={isDue}
                revisionAt={item.revision_at}
                topicTag={item.topic_tag}
                onAdvance={goNext}
              />
            )}
          </div>
        </div>
      </div>

      {isOwner && isEditMode && (
        <button
          aria-label={`Delete ${item.title}`}
          className="touch-target shrink-0 text-muted-foreground hover:text-destructive"
          disabled={isPending}
          type="button"
          onClick={remove}
        >
          <Trash2 aria-hidden className="h-4 w-4" />
        </button>
      )}
    </li>
  );
}
