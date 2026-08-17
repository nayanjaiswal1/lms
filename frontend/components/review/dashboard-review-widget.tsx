"use client";

import * as React from "react";
import { toast } from "sonner";
import { Brain, RotateCcw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { submitReviewAction } from "@/app/(app)/review/actions";
import type { SRSCard } from "@/lib/server/srs";

const QUALITY_AGAIN = 0;
const QUALITY_HARD = 1;
const QUALITY_GOOD = 2;
const QUALITY_EASY = 3;

interface QueueState {
  index: number;
  revealed: boolean;
  submitting: boolean;
  reviewedCount: number;
}

interface DashboardReviewWidgetProps {
  cards: SRSCard[];
}

// Compact inline reviewer for the dashboard's "Review cards" widget — the
// same flip/rate flow as the full /review page, without navigating there.
export function DashboardReviewWidget({ cards }: DashboardReviewWidgetProps) {
  const [state, setState] = React.useState<QueueState>({
    index: 0,
    revealed: false,
    submitting: false,
    reviewedCount: 0,
  });

  const card = cards[state.index];

  async function handleRate(quality: number) {
    if (state.submitting || !card) return;
    setState((s) => ({ ...s, submitting: true }));

    const result = await submitReviewAction(card.id, quality);
    if (!result.ok) {
      toast.error(result.error ?? "Could not save your review.");
      setState((s) => ({ ...s, submitting: false }));
      return;
    }

    setState((s) => ({
      index: s.index + 1,
      revealed: false,
      submitting: false,
      reviewedCount: s.reviewedCount + 1,
    }));
  }

  if (!card) {
    return (
      <section className="card-base flex items-center gap-4 p-5">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
          <Brain aria-hidden className="h-5 w-5 text-primary" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">Review cards</p>
          <p className="text-xs text-muted-foreground">
            {state.reviewedCount > 0
              ? `Reviewed ${state.reviewedCount} card${state.reviewedCount !== 1 ? "s" : ""} — all caught up`
              : "You're all caught up"}
          </p>
        </div>
      </section>
    );
  }

  return (
    <section className="card-base flex flex-col gap-4 p-5">
      <div className="flex items-center justify-between gap-4">
        <h2 className="subsection-title">Review cards</h2>
        <p className="text-xs tabular-nums text-muted-foreground">
          {state.index + 1} of {cards.length}
        </p>
      </div>

      {!state.revealed ? (
        <>
          <p className="text-center text-sm font-medium leading-relaxed">{card.front}</p>
          <Button size="sm" variant="outline" onClick={() => setState((s) => ({ ...s, revealed: true }))}>
            <RotateCcw aria-hidden className="mr-2 h-3.5 w-3.5" />
            Show Answer
          </Button>
        </>
      ) : (
        <>
          <p className="text-center text-xs text-muted-foreground">{card.front}</p>
          <hr className="border-border" />
          <p className="text-center text-sm font-medium leading-relaxed">{card.back}</p>
          <div className="flex overflow-hidden rounded-lg border border-border">
            <RatingButton disabled={state.submitting} label="Again" variant="again" onClick={() => handleRate(QUALITY_AGAIN)} />
            <RatingButton disabled={state.submitting} label="Hard" variant="hard" onClick={() => handleRate(QUALITY_HARD)} />
            <RatingButton disabled={state.submitting} label="Good" variant="good" onClick={() => handleRate(QUALITY_GOOD)} />
            <RatingButton disabled={state.submitting} label="Easy" variant="easy" onClick={() => handleRate(QUALITY_EASY)} />
          </div>
        </>
      )}
    </section>
  );
}

interface RatingButtonProps {
  label: string;
  variant: "again" | "hard" | "good" | "easy";
  disabled: boolean;
  onClick: () => void;
}

// success (green), not primary (amber), for "good" — primary and warning
// share the same amber hue in globals.css, so pairing them here made Hard
// and Good render as nearly the same color.
const ratingStyles: Record<RatingButtonProps["variant"], string> = {
  again: "text-destructive hover:bg-destructive/10",
  hard:  "text-warning hover:bg-warning/10",
  good:  "text-success hover:bg-success/10",
  easy:  "text-ai hover:bg-ai/10",
};

// One joined pill instead of 4 separate boxed buttons — each segment keeps
// its own rating color, a shared divider (border-l, skipped on the first)
// replaces the individual borders the container used to draw.
function RatingButton({ label, variant, disabled, onClick }: RatingButtonProps) {
  return (
    <button
      className={`touch-target flex-1 border-l border-border text-xs font-semibold transition-colors duration-fast ease-smooth first:border-l-0 disabled:pointer-events-none disabled:opacity-50 ${ratingStyles[variant]}`}
      disabled={disabled}
      type="button"
      onClick={onClick}
    >
      {label}
    </button>
  );
}
