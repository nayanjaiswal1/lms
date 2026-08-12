import { HabitBoard } from "@/components/habits/habit-board";
import { journalSans, journalSerif } from "@/components/habits/journal-fonts";
import "@/components/habits/journal-theme.css";
import { getHabitMonth } from "@/lib/server/habits";
import { cn } from "@/lib/utils";

export const metadata = { title: "Habit Tracker" };

function currentMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

interface HabitsPageProps {
  searchParams: Promise<{ month?: string }>;
}

export default async function HabitsPage({ searchParams }: HabitsPageProps) {
  const { month: monthParam } = await searchParams;
  const month = monthParam ?? currentMonth();
  const view = await getHabitMonth(month);

  return (
    // Negative margin cancels .app-content's own padding so the journal
    // background reaches its edges instead of leaving a gap of the default
    // app background around it; the padding is re-applied here so content
    // spacing is unchanged.
    <div
      className={cn(
        "habits-journal min-h-full -m-4 p-4 sm:-m-6 sm:p-6 lg:-m-8 lg:p-8",
        journalSans.variable,
        journalSerif.variable,
      )}
    >
      <main className="page-container">
        <div className="page-header">
          <h1 className="page-title">Habit Tracker</h1>
        </div>
        {/* Keyed by month so switching months remounts with fresh state instead
            of a stale local edit from the previous month leaking through. */}
        <HabitBoard initialCompletions={view.completions} initialHabits={view.habits} key={month} month={month} />
      </main>
    </div>
  );
}
