"use client";

import * as React from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Brain, RotateCcw, ArrowLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import { submitReviewAction } from "@/app/(app)/review/actions";
import type { SRSCard } from "@/lib/server/srs";
import ROUTES from "@/lib/routes";

// Quality levels mirror the SM-2 scale sent to the backend.
const QUALITY_AGAIN = 0;
const QUALITY_HARD = 1;
const QUALITY_GOOD = 2;
const QUALITY_EASY = 3;

type SessionState = "idle" | "revealed" | "complete";

interface RatingCounts {
  again: number;
  hard: number;
  good: number;
  easy: number;
}

interface ReviewSessionProps {
  cards: SRSCard[];
}

export function ReviewSession({ cards }: ReviewSessionProps) {
  const [index, setIndex] = React.useState(0);
  const [sessionState, setSessionState] = React.useState<SessionState>("idle");
  const [submitting, setSubmitting] = React.useState(false);
  const [ratings, setRatings] = React.useState<RatingCounts>({
    again: 0,
    hard: 0,
    good: 0,
    easy: 0,
  });

  const total = cards.length;
  const card = cards[index];

  function handleShowAnswer() {
    setSessionState("revealed");
  }

  async function handleRate(quality: number) {
    if (submitting || !card) return;
    setSubmitting(true);

    const result = await submitReviewAction(card.id, quality);
    if (!result.ok) {
      toast.error(result.error ?? "Could not save your review.");
      setSubmitting(false);
      return;
    }

    setRatings((prev) => {
      const next = { ...prev };
      if (quality === QUALITY_AGAIN) next.again += 1;
      else if (quality === QUALITY_HARD) next.hard += 1;
      else if (quality === QUALITY_GOOD) next.good += 1;
      else if (quality === QUALITY_EASY) next.easy += 1;
      return next;
    });

    const nextIndex = index + 1;
    if (nextIndex >= total) {
      setSessionState("complete");
    } else {
      setIndex(nextIndex);
      setSessionState("idle");
    }
    setSubmitting(false);
  }

  if (sessionState === "complete") {
    const reviewed = ratings.again + ratings.hard + ratings.good + ratings.easy;
    return (
      <main className="page-container py-10">
        <div className="mx-auto max-w-lg">
          <div className="card-base flex flex-col items-center gap-6 p-8 text-center">
            <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10">
              <Brain aria-hidden className="h-7 w-7 text-primary" />
            </span>
            <div className="flex flex-col gap-1">
              <h1 className="text-2xl font-bold tracking-tight">Session complete</h1>
              <p className="text-muted-foreground">
                You reviewed {reviewed} card{reviewed !== 1 ? "s" : ""}.
              </p>
            </div>

            <div className="w-full grid-responsive-2 gap-3">
              <RatingSummaryItem label="Again" count={ratings.again} colorClass="text-destructive" />
              <RatingSummaryItem label="Hard" count={ratings.hard} colorClass="text-warning-foreground" />
              <RatingSummaryItem label="Good" count={ratings.good} colorClass="text-primary" />
              <RatingSummaryItem label="Easy" count={ratings.easy} colorClass="text-ai" />
            </div>

            <Button asChild className="w-full sm:w-auto">
              <Link href={ROUTES.DASHBOARD}>
                <ArrowLeft aria-hidden className="mr-2 h-4 w-4" />
                Back to Dashboard
              </Link>
            </Button>
          </div>
        </div>
      </main>
    );
  }

  if (!card) return null;

  const progressPct = total > 0 ? (index / total) * 100 : 0;

  return (
    <main className="page-container py-10">
      <div className="mx-auto max-w-2xl">
        {/* Header: back link + progress */}
        <div className="mb-6 flex flex-col gap-3">
          <div className="flex items-center justify-between gap-4">
            <Button asChild size="sm" variant="ghost">
              <Link href={ROUTES.DASHBOARD}>
                <ArrowLeft aria-hidden className="mr-1 h-4 w-4" />
                Dashboard
              </Link>
            </Button>
            <p className="text-sm font-medium tabular-nums text-muted-foreground">
              Card {index + 1} of {total}
            </p>
          </div>
          <div className="progress-track h-1.5">
            {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width requires inline style */}
            <div
              className="progress-fill h-full bg-primary"
              style={{ width: `${progressPct}%` }}
              aria-hidden
            />
          </div>
        </div>

        {/* Card face */}
        <div className="card-base flex min-h-64 flex-col gap-6 p-8">
          {sessionState === "idle" ? (
            <>
              <div className="flex flex-1 items-center justify-center">
                <p className="text-center text-xl font-semibold leading-relaxed">{card.front}</p>
              </div>
              <Button className="w-full" size="lg" onClick={handleShowAnswer}>
                <RotateCcw aria-hidden className="mr-2 h-4 w-4" />
                Show Answer
              </Button>
            </>
          ) : (
            <>
              <p className="text-center text-sm text-muted-foreground">{card.front}</p>
              <hr className="border-border" />
              <div className="flex flex-1 items-center justify-center">
                <p className="text-center text-xl font-semibold leading-relaxed">{card.back}</p>
              </div>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <RatingButton
                  disabled={submitting}
                  label="Again"
                  sublabel="< 1 min"
                  variant="again"
                  onClick={() => handleRate(QUALITY_AGAIN)}
                />
                <RatingButton
                  disabled={submitting}
                  label="Hard"
                  sublabel="< 10 min"
                  variant="hard"
                  onClick={() => handleRate(QUALITY_HARD)}
                />
                <RatingButton
                  disabled={submitting}
                  label="Good"
                  sublabel="Good"
                  variant="good"
                  onClick={() => handleRate(QUALITY_GOOD)}
                />
                <RatingButton
                  disabled={submitting}
                  label="Easy"
                  sublabel="Easy"
                  variant="easy"
                  onClick={() => handleRate(QUALITY_EASY)}
                />
              </div>
            </>
          )}
        </div>
      </div>
    </main>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────────

interface RatingButtonProps {
  label: string;
  sublabel: string;
  variant: "again" | "hard" | "good" | "easy";
  disabled: boolean;
  onClick: () => void;
}

const ratingStyles: Record<RatingButtonProps["variant"], string> = {
  again: "border-destructive/50 text-destructive hover:bg-destructive/10",
  hard:  "border-warning/50 text-warning-foreground hover:bg-warning/10",
  good:  "border-primary/50 text-primary hover:bg-primary/10",
  easy:  "border-ai/50 text-ai hover:bg-ai/10",
};

function RatingButton({ label, sublabel, variant, disabled, onClick }: RatingButtonProps) {
  return (
    <button
      className={`flex min-h-11 flex-col items-center justify-center gap-0.5 rounded-lg border px-3 py-2.5 text-sm font-semibold transition-colors duration-fast ease-smooth disabled:pointer-events-none disabled:opacity-50 ${ratingStyles[variant]}`}
      disabled={disabled}
      type="button"
      onClick={onClick}
    >
      <span>{label}</span>
      <span className="text-xs font-normal opacity-70">{sublabel}</span>
    </button>
  );
}

interface RatingSummaryItemProps {
  label: string;
  count: number;
  colorClass: string;
}

function RatingSummaryItem({ label, count, colorClass }: RatingSummaryItemProps) {
  return (
    <div className="card-base flex flex-col items-center gap-1 p-4 text-center">
      <p className={`text-2xl font-bold tabular-nums ${colorClass}`}>{count}</p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}
