import { Flame } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import type { HabitMonth } from "@/app/(app)/users/[id]/types";

export function HabitsTab({ habitMonth }: { habitMonth: HabitMonth }) {
  if (habitMonth.habits.length === 0) {
    return (
      <div className="empty-state">
        <Flame aria-hidden className="empty-state-icon" />
        <p>No habits set up.</p>
      </div>
    );
  }

  return (
    <div className="card-base p-6">
      <h3 className="subsection-title text-foreground mb-2">This month</h3>
      {habitMonth.habits.map((habit) => {
        const completions = habitMonth.completions.filter((c) => c.habit_id === habit.id);
        const total = completions.reduce((sum, c) => sum + c.count, 0);
        return (
          <div className="flex items-center gap-3 py-3 border-b border-border last:border-0" key={habit.id}>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-foreground truncate">{habit.name}</p>
              <div className="flex flex-wrap items-center gap-1.5 mt-1">
                <Badge variant="outline">{habit.cadence}</Badge>
                {habit.tags.map((tag) => (
                  <Badge key={tag} variant="secondary">
                    {tag}
                  </Badge>
                ))}
              </div>
            </div>
            <div className="text-right shrink-0">
              <p className="text-lg font-semibold text-foreground">{total}</p>
              <p className="text-xs text-muted-foreground">logged days</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
