import { CalendarDays, History, Timer } from "lucide-react";
import { formatDate } from "@/lib/tickets/format";
import { formatDuration, formatLastActive } from "@/lib/mentoring/format";

interface Props {
  lastActiveAt: string | null;
  totalMentorshipHours: number | null;
  joinedAt: string;
}

// Sidebar "Metadata" card — last-active is the one field here with no other
// home on the page (unlike hours/joined, which used to sit in a bare <p>
// list); grouping all three under one heading matches the mockup's split
// between "live stats" (insights card above) and "static facts" (this one).
export function MentorMetadataCard({ lastActiveAt, totalMentorshipHours, joinedAt }: Props) {
  const lastActiveLabel = formatLastActive(lastActiveAt);
  const hoursLabel = formatDuration(totalMentorshipHours);

  return (
    <section className="rounded-xl border border-border bg-card p-6">
      <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-muted-foreground">Metadata</h2>
      <div className="flex flex-col gap-3">
        {lastActiveLabel && (
          <p className="flex items-center gap-2 text-sm text-foreground">
            <History aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
            Last active {lastActiveLabel}
          </p>
        )}
        {hoursLabel && (
          <p className="flex items-center gap-2 text-sm text-foreground">
            <Timer aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
            {hoursLabel} of mentorship delivered
          </p>
        )}
        <p className="flex items-center gap-2 text-sm text-foreground">
          <CalendarDays aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
          Joined {formatDate(joinedAt)}
        </p>
      </div>
    </section>
  );
}
