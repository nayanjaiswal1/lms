import Link from "next/link";

import type { DiaryEntryPreview } from "@/lib/server/diary";
import ROUTES from "@/lib/routes";

interface DiaryCalendarProps {
  entries: DiaryEntryPreview[];
}

interface Cell {
  day: number;
  date: string;
  hasEntry: boolean;
}

// Static current-month grid — no prev/next navigation in v1.
// ponytail: month is always "today"'s month; add a client nav control if
// users ask to browse older months instead of scrolling the feed beside it.
function buildMonthCells(entryDates: Set<string>): Cell[] {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const leadingBlanks = new Date(year, month, 1).getDay();

  const cells: Cell[] = Array.from({ length: leadingBlanks }, () => ({ day: 0, date: "", hasEntry: false }));
  for (let day = 1; day <= daysInMonth; day++) {
    const iso = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    cells.push({ day, date: iso, hasEntry: entryDates.has(iso) });
  }
  return cells;
}

// Month calendar with entry-dot indicators — sits above the To-Do/Buy List
// in the diary sidebar (see components/diary/diary-page-shell.tsx). A day
// with an entry links straight to that day's editable entry.
export function DiaryCalendar({ entries }: DiaryCalendarProps) {
  const entryDates = new Set(entries.map((e) => e.entry_date));
  const cells = buildMonthCells(entryDates);
  const monthLabel = new Date().toLocaleDateString(undefined, { month: "long", year: "numeric" });

  return (
    <div className="card-base p-4">
      <h2 className="diary-paper-headline mb-3 text-base font-semibold text-foreground">{monthLabel}</h2>
      <div className="grid grid-cols-7 gap-1 text-center">
        {["S", "M", "T", "W", "T", "F", "S"].map((label, i) => (
          <span className="text-xs text-muted-foreground" key={i}>
            {label}
          </span>
        ))}
        {cells.map((cell, i) =>
          cell.hasEntry ? (
            <Link
              className="relative mx-auto flex size-7 items-center justify-center rounded-full text-sm text-foreground transition-colors duration-fast ease-smooth hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              href={ROUTES.diaryEntry(cell.date)}
              key={i}
            >
              {cell.day}
              <span className="absolute bottom-0.5 size-1 rounded-full bg-primary" />
            </Link>
          ) : (
            <span
              className="relative mx-auto flex size-7 items-center justify-center rounded-full text-sm text-foreground"
              key={i}
            >
              {cell.day > 0 && cell.day}
            </span>
          ),
        )}
      </div>
    </div>
  );
}
