import { BookOpen } from "lucide-react";
import { latestMetadataEntry, sumNumericField, type MetadataByKey } from "@/lib/habits/summaries";
import type { Habit } from "@/lib/server/habits";

interface ReadingProgressCardProps {
  habits: Habit[];
  month: string;
  metadata: MetadataByKey;
}

// Real data only — the most recent logged entry plus this month's page total
// for the user's "reading"-type habit, never sample numbers.
export function ReadingProgressCard({ habits, month, metadata }: ReadingProgressCardProps) {
  const habit = habits.find((h) => h.type === "reading");
  const entry = habit ? latestMetadataEntry(habit, month, metadata) : null;
  const totalPages = habit ? sumNumericField(habit, month, metadata, "pages") : 0;

  return (
    <section className="rounded-lg border border-border p-6">
      <h2 className="habits-journal-headline mb-4 border-b border-border pb-2 text-xs font-semibold uppercase tracking-widest text-muted-foreground">
        Reading Progress
      </h2>
      {!habit ? (
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">Add a Reading habit to see this card.</p>
        </div>
      ) : !entry ? (
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">Click {habit.name} on the grid to log today&apos;s reading.</p>
        </div>
      ) : (
        <div className="flex h-full flex-col gap-6 rounded-md bg-primary/5 p-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="flex flex-col">
              <span className="text-[10px] uppercase tracking-widest text-primary">Book / Topic</span>
              <span className="text-sm">{stringField(entry.book) ?? "—"}</span>
            </div>
            <div className="flex flex-col text-right">
              <span className="text-[10px] uppercase tracking-widest text-primary">Pages This Month</span>
              <span className="flex items-center justify-end gap-1.5 text-sm">
                <BookOpen aria-hidden className="size-3.5 text-primary" />
                {totalPages}
              </span>
            </div>
          </div>
          {stringField(entry.takeaway) && (
            <p className="mt-auto border-t border-border pt-4 text-xs italic text-muted-foreground">
              &ldquo;{stringField(entry.takeaway)}&rdquo;
            </p>
          )}
        </div>
      )}
    </section>
  );
}

function stringField(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : typeof value === "number" ? String(value) : null;
}
