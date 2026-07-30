"use client";

import { useTransition } from "react";
import Link from "next/link";
import { Check, Circle, ExternalLink, Flame, RotateCcw, Star } from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import { updateFaqStarredAction, updateFaqStatusAction } from "@/lib/interview-exp/actions";
import type { FaqItem, FaqStatus } from "@/lib/server/interview-exp";

// Mirrors sheets' status cycle exactly (components/sheets/sheet-table-row.tsx)
// — same 3 states, same order, same icon/color mapping — just applied to
// interview_exp_qna instead of sheet_items.
const NEXT_STATUS: Record<FaqStatus, FaqStatus> = {
  todo: "done",
  done: "revisit",
  revisit: "todo",
};

const STATUS_ICON: Record<FaqStatus, typeof Check> = {
  todo: Circle,
  done: Check,
  revisit: RotateCcw,
};

const STATUS_LABEL: Record<FaqStatus, string> = {
  todo: "Mark as solved",
  done: "Mark for revision",
  revisit: "Mark as unsolved",
};

const STATUS_CLASS: Record<FaqStatus, string> = {
  todo: "text-muted-foreground border-border",
  done: "text-success border-success bg-success/10",
  revisit: "text-warning border-warning bg-warning/10",
};

interface FaqRowProps {
  item: FaqItem;
}

export function FaqRow({ item }: FaqRowProps) {
  const [isPending, startTransition] = useTransition();
  const StatusIcon = STATUS_ICON[item.status];

  function cycleStatus() {
    startTransition(async () => {
      await updateFaqStatusAction(item.qna_id, NEXT_STATUS[item.status]);
    });
  }

  function toggleStarred() {
    startTransition(async () => {
      await updateFaqStarredAction(item.qna_id, !item.is_starred);
    });
  }

  return (
    <li className="flex items-center gap-3 px-4 py-3">
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
        <StatusIcon className="h-4 w-4" />
      </button>

      <div className="min-w-0 flex-1">
        <p className="truncate font-medium text-foreground">{item.question}</p>
        <p className="truncate text-xs text-muted-foreground">
          {item.company} · {item.position}
        </p>
      </div>

      <span className="flex shrink-0 items-center gap-1 text-xs text-muted-foreground" title="Vote score">
        <Flame aria-hidden className="h-3.5 w-3.5" />
        {item.score}
      </span>

      <button
        aria-label={item.is_starred ? "Unstar" : "Star"}
        aria-pressed={item.is_starred}
        className="touch-target flex items-center justify-center shrink-0"
        disabled={isPending}
        type="button"
        onClick={toggleStarred}
      >
        <Star className={cn("h-4 w-4", item.is_starred ? "fill-primary text-primary" : "text-muted-foreground")} />
      </button>

      <Link
        aria-label={`Open ${item.question}`}
        className="touch-target flex items-center justify-center shrink-0 text-muted-foreground hover:text-foreground"
        href={ROUTES.interviewExpPost(item.post_id)}
      >
        <ExternalLink className="h-4 w-4" />
      </Link>
    </li>
  );
}
