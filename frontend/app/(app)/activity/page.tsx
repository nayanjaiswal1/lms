import type { Metadata } from "next";
import Link from "next/link";
import { History } from "lucide-react";

import { Button } from "@/components/ui/button";
import { ActivityTimeline } from "@/components/activity/activity-timeline";
import { getActivity } from "@/lib/server/activity";

export const metadata: Metadata = {
  title: "Activity",
  description: "What you did, and when — a day-by-day timeline to help you revise and track progress.",
};

interface ActivityPageProps {
  searchParams: Promise<{ cursor?: string }>;
}

export default async function ActivityPage({ searchParams }: ActivityPageProps) {
  const { cursor } = await searchParams;
  const page = await getActivity({ cursor });

  return (
    <main className="page-container">
      <div className="page-header">
        <h1 className="page-title">Activity</h1>
      </div>

      {page.entries.length === 0 ? (
        <div className="empty-state">
          <History aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground">Nothing tracked yet — complete a module or review a card to see it here.</p>
        </div>
      ) : (
        <>
          <ActivityTimeline entries={page.entries} />

          {page.next_cursor && (
            <div className="flex justify-center pt-8">
              <Button asChild variant="secondary">
                <Link href={`?cursor=${encodeURIComponent(page.next_cursor)}`}>Load more</Link>
              </Button>
            </div>
          )}
        </>
      )}
    </main>
  );
}
