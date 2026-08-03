import { ActivityRow } from "@/components/activity/activity-row";
import type { ActivityEntry } from "@/lib/server/activity";

function dayHeading(day: string): string {
  const date = new Date(`${day}T00:00:00Z`);
  const today = new Date();
  const todayUTC = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  const diffDays = Math.round((date.getTime() - todayUTC) / 86_400_000);

  if (diffDays === 0) return "Today";
  if (diffDays === -1) return "Yesterday";
  return date.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", timeZone: "UTC" });
}

// Entries arrive newest-first from the API and grouping-by-day preserves
// that order — no re-sort needed here.
function groupByDay(entries: ActivityEntry[]): { day: string; entries: ActivityEntry[] }[] {
  const groups: { day: string; entries: ActivityEntry[] }[] = [];
  for (const entry of entries) {
    const last = groups[groups.length - 1];
    if (last && last.day === entry.day) {
      last.entries.push(entry);
    } else {
      groups.push({ day: entry.day, entries: [entry] });
    }
  }
  return groups;
}

export function ActivityTimeline({ entries }: { entries: ActivityEntry[] }) {
  const groups = groupByDay(entries);

  return (
    <div className="flex flex-col gap-8">
      {groups.map((group) => (
        <section key={group.day}>
          <h2 className="subsection-title mb-3">{dayHeading(group.day)}</h2>
          <div className="flex flex-col gap-2">
            {group.entries.map((entry) => (
              <ActivityRow entry={entry} key={entry.key} />
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
