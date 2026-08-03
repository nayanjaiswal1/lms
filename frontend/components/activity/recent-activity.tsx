import Link from "next/link";
import { ArrowRight, History } from "lucide-react";

import { ActivityRow } from "@/components/activity/activity-row";
import ROUTES from "@/lib/routes";
import type { ActivityEntry } from "@/lib/server/activity";

export function RecentActivity({ entries }: { entries: ActivityEntry[] }) {
  return (
    <section className="card-base flex flex-col gap-4 p-5">
      <div className="flex items-center justify-between gap-4">
        <h2 className="subsection-title">Recent activity</h2>
        <Link className="flex items-center gap-1 text-sm text-primary hover:underline" href={ROUTES.ACTIVITY}>
          View all <ArrowRight aria-hidden className="h-3.5 w-3.5" />
        </Link>
      </div>

      {entries.length === 0 ? (
        <div className="empty-state">
          <History aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground">Nothing tracked yet — complete a module or review a card to see it here.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-1">
          {entries.map((entry) => (
            <ActivityRow entry={entry} key={entry.key} />
          ))}
        </div>
      )}
    </section>
  );
}
