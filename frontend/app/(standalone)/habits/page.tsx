import Link from "next/link";
import { Compass } from "lucide-react";
import { HabitBoard } from "@/components/habits/habit-board";
import { journalSans, journalSerif } from "@/components/habits/journal-fonts";
import { HabitViewSwitch } from "@/components/habits/habit-view-switch";
import "@/components/habits/journal-theme.css";
import { getHabitMonth } from "@/lib/server/habits";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

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
    <div
      className={cn(
        "habits-journal min-h-full p-4 sm:p-6 lg:p-8",
        journalSans.variable,
        journalSerif.variable,
      )}
    >
      <main className="page-container relative">
        <div className="absolute right-4 top-4 z-raised flex items-center gap-2 sm:right-6 sm:top-6">
          <HabitViewSwitch />
          <Link
            aria-label="Open What Now?"
            className="touch-target rounded-full border border-border bg-background text-foreground shadow-card transition-colors duration-fast ease-smooth hover:bg-accent"
            href={ROUTES.NOW}
            title="Open What Now?"
          >
            <Compass aria-hidden className="h-5 w-5" />
          </Link>
        </div>
        <div className="page-header py-2">
          <h1 className="page-title text-xl">Habit Tracker</h1>
        </div>
        {/* Keyed by month so switching months remounts with fresh state instead
            of a stale local edit from the previous month leaking through. */}
        <HabitBoard initialCompletions={view.completions} initialHabits={view.habits} key={month} month={month} />
      </main>
    </div>
  );
}
