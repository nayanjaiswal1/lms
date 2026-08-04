import { HabitBoard } from "@/components/habits/habit-board";
import { getHabitMonth } from "@/lib/server/habits";

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
    <main className="page-container">
      <div className="page-header">
        <h1 className="page-title">Habit Tracker</h1>
      </div>
      {/* Keyed by month so switching months remounts with fresh state instead
          of a stale local edit from the previous month leaking through. */}
      <HabitBoard initialCompletions={view.completions} initialHabits={view.habits} key={month} month={month} />
    </main>
  );
}
