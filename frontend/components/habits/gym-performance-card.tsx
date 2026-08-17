import { Zap } from "lucide-react";
import { latestMetadataEntry, type MetadataByKey } from "@/lib/habits/summaries";
import type { Habit } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

interface GymPerformanceCardProps {
  habits: Habit[];
  month: string;
  metadata: MetadataByKey;
}

// Real data only — the most recent logged entry for the user's "gym"-type
// habit (see habit-entry-form.tsx), never sample numbers.
export function GymPerformanceCard({ habits, month, metadata }: GymPerformanceCardProps) {
  const habit = habits.find((h) => h.type === "gym");
  const entry = habit ? latestMetadataEntry(habit, month, metadata) : null;

  return (
    <section className="rounded-lg border border-border p-6">
      <h2 className="habits-journal-headline mb-4 border-b border-border pb-2 text-xs font-semibold uppercase tracking-widest text-muted-foreground">
        Gym Performance
      </h2>
      {!habit ? (
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">Add a Gym habit to see this card.</p>
        </div>
      ) : !entry ? (
        <div className="empty-state py-8">
          <p className="text-sm text-muted-foreground">Click {habit.name} on the grid to log today&apos;s workout.</p>
        </div>
      ) : (
        <div className="flex h-full flex-col gap-6 rounded-md bg-primary/5 p-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="flex flex-col">
              <span className="text-[10px] uppercase tracking-widest text-primary">Workout Type</span>
              <span className="text-sm">{stringField(entry.workout_type) ?? "—"}</span>
            </div>
            <div className="flex flex-col text-right">
              <span className="text-[10px] uppercase tracking-widest text-primary">Duration</span>
              <span className="text-sm">
                {stringField(entry.duration_minutes) ? `${entry.duration_minutes} Minutes` : "—"}
              </span>
            </div>
          </div>
          {typeof entry.intensity === "number" && (
            <div className="flex flex-col">
              <span className="text-[10px] uppercase tracking-widest text-primary">Intensity</span>
              <div className="mt-1 flex gap-1">
                {Array.from({ length: 5 }, (_, i) => (
                  <Zap
                    aria-hidden
                    className={cn("size-3.5", i < (entry.intensity as number) ? "text-primary" : "text-muted-foreground/30")}
                    key={i}
                  />
                ))}
              </div>
            </div>
          )}
          {stringField(entry.notes) && (
            <p className="mt-auto border-t border-border pt-4 text-xs italic text-muted-foreground">
              &ldquo;{stringField(entry.notes)}&rdquo;
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
