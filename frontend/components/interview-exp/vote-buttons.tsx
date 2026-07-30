"use client";

import { useTransition } from "react";
import { ChevronDown, ChevronUp } from "lucide-react";
import { cn } from "@/lib/utils";
import { voteAction } from "@/lib/interview-exp/actions";

interface VoteButtonsProps {
  targetType: "qna" | "comment";
  targetId: string;
  score: number;
  myVote: number;
}

export function VoteButtons({ targetType, targetId, score, myVote }: VoteButtonsProps) {
  const [isPending, startTransition] = useTransition();

  function cast(value: -1 | 1) {
    const next = myVote === value ? 0 : value;
    startTransition(async () => {
      await voteAction(targetType, targetId, next);
    });
  }

  return (
    <div className="flex flex-col items-center gap-0.5">
      <button
        aria-label="Upvote"
        aria-pressed={myVote === 1}
        className={cn(
          "touch-target flex items-center justify-center rounded-md text-muted-foreground hover:bg-muted",
          myVote === 1 && "text-primary",
        )}
        disabled={isPending}
        type="button"
        onClick={() => cast(1)}
      >
        <ChevronUp className="h-4 w-4" />
      </button>
      <span className="min-w-4 text-center text-xs font-semibold text-foreground">{score}</span>
      <button
        aria-label="Downvote"
        aria-pressed={myVote === -1}
        className={cn(
          "touch-target flex items-center justify-center rounded-md text-muted-foreground hover:bg-muted",
          myVote === -1 && "text-destructive",
        )}
        disabled={isPending}
        type="button"
        onClick={() => cast(-1)}
      >
        <ChevronDown className="h-4 w-4" />
      </button>
    </div>
  );
}
