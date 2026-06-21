import type { Metadata } from "next";
import Link from "next/link";
import { Brain } from "lucide-react";

import { Button } from "@/components/ui/button";
import { ReviewSession } from "@/components/review/review-session";
import { getDueCards } from "@/lib/server/srs";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Review Cards" };

function formatNextReviewHint(cards: { due_date: string }[]): string | null {
  if (cards.length === 0) return null;
  const dates = cards.map((c) => new Date(c.due_date).getTime()).filter(Number.isFinite);
  if (dates.length === 0) return null;
  const soonest = new Date(Math.min(...dates));
  const now = new Date();
  const diffMs = soonest.getTime() - now.getTime();
  const diffHours = Math.ceil(diffMs / (1000 * 60 * 60));
  if (diffHours <= 1) return "next card due in less than an hour";
  if (diffHours < 24) return `next card due in ${diffHours} hours`;
  const diffDays = Math.ceil(diffHours / 24);
  return `next card due in ${diffDays} day${diffDays !== 1 ? "s" : ""}`;
}

export default async function ReviewPage() {
  let cards: Awaited<ReturnType<typeof getDueCards>>["cards"] = [];
  let total = 0;

  try {
    const data = await getDueCards();
    cards = data.cards;
    total = data.total;
  } catch {
    // Render empty state on error; the session component can only show cards
    // that were fetched — failing silently degrades gracefully here.
  }

  if (total === 0) {
    const hint = formatNextReviewHint(cards);
    return (
      <main className="page-container py-10">
        <div className="empty-state">
          <Brain aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground font-medium">You&apos;re all caught up!</p>
          {hint && (
            <p className="text-sm text-muted-foreground">{hint.charAt(0).toUpperCase() + hint.slice(1)}.</p>
          )}
          <Button asChild size="sm" variant="outline">
            <Link href={ROUTES.DASHBOARD}>Back to Dashboard</Link>
          </Button>
        </div>
      </main>
    );
  }

  return <ReviewSession cards={cards} />;
}
