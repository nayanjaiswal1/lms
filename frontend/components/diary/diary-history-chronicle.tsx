import type { DiaryEntryPreview } from "@/lib/server/diary";

interface DiaryHistoryChronicleProps {
  entries: DiaryEntryPreview[];
}

function formatLongDate(date: string): string {
  return new Date(`${date}T00:00:00`).toLocaleDateString(undefined, {
    month: "long",
    day: "numeric",
    year: "numeric",
  });
}

// Static current-month grid — no prev/next navigation in v1.
// ponytail: month is always "today"'s month; add a client nav control if
// users ask to browse older months from the calendar instead of scrolling
// the feed below.
function buildMonthCells(entryDates: Set<string>): { day: number; hasEntry: boolean }[] {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const leadingBlanks = new Date(year, month, 1).getDay();

  const cells: { day: number; hasEntry: boolean }[] = Array.from({ length: leadingBlanks }, () => ({
    day: 0,
    hasEntry: false,
  }));
  for (let day = 1; day <= daysInMonth; day++) {
    const iso = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    cells.push({ day, hasEntry: entryDates.has(iso) });
  }
  return cells;
}

// Desktop (lg+) history view: a static month calendar with entry-dot
// indicators alongside the full feed — the richer "Chronicle" treatment of
// the same data the mobile timeline shows, not a separate feature.
export function DiaryHistoryChronicle({ entries }: DiaryHistoryChronicleProps) {
  const entryDates = new Set(entries.map((e) => e.entry_date));
  const cells = buildMonthCells(entryDates);
  const monthLabel = new Date().toLocaleDateString(undefined, { month: "long", year: "numeric" });

  return (
    <div className="flex gap-8">
      <aside className="w-56 shrink-0">
        <div className="card-base p-4">
          <h2 className="diary-paper-headline mb-3 text-base font-semibold text-foreground">{monthLabel}</h2>
          <div className="grid grid-cols-7 gap-1 text-center">
            {["S", "M", "T", "W", "T", "F", "S"].map((label, i) => (
              <span className="text-xs text-muted-foreground" key={i}>
                {label}
              </span>
            ))}
            {cells.map((cell, i) => (
              <span
                className="relative mx-auto flex size-7 items-center justify-center rounded-full text-sm text-foreground"
                key={i}
              >
                {cell.day > 0 && cell.day}
                {cell.hasEntry && <span className="absolute bottom-0.5 size-1 rounded-full bg-primary" />}
              </span>
            ))}
          </div>
        </div>
      </aside>

      <div className="flex flex-1 flex-col gap-8">
        {entries.map((entry) => (
          <article className="border-t border-border pt-4" key={entry.id}>
            <time className="diary-paper-headline text-sm font-semibold uppercase tracking-wide text-primary">
              {formatLongDate(entry.entry_date)}
            </time>
            <p className="mt-2 text-base leading-8 text-foreground">{entry.preview}</p>
          </article>
        ))}
      </div>
    </div>
  );
}
