"use client";

import { useEffect, useRef } from "react";
import { DailyHabitWheel } from "@/components/habits/daily-habit-wheel";
import { GymPerformanceCard } from "@/components/habits/gym-performance-card";
import { HabitGrid } from "@/components/habits/habit-grid";
import { ReadingProgressCard } from "@/components/habits/reading-progress-card";
import { SleepQualityCard } from "@/components/habits/sleep-quality-chart";
import { monthLabel } from "@/lib/habits/dates";
import type { MetadataByKey } from "@/lib/habits/summaries";
import type { Habit } from "@/lib/server/habits";

interface HabitPrintExportProps {
  habits: Habit[];
  month: string;
  counts: Map<string, number>;
  metadata: MetadataByKey;
}

const noop = () => {};
const noopAsync = async () => false;

// ponytail: a habit count/day count extreme enough to want >3x could exist,
// but nothing today produces one — raise this if a real wheel ever needs it.
const MAX_SCALE = 3;
// Matches journal-theme.css's fallback print row height — the baseline
// scaleGrid measures the table's natural size at before computing a target.
const DEFAULT_ROW_HEIGHT_PX = 52;
// Floor scaleGrid won't shrink rows past for a many-habit table — matches
// the on-screen h-9/min-h-9 size, below which a checkmark stops fitting.
const MIN_ROW_HEIGHT_PX = 36;

// Wheel and table render at their natural size (whatever the current habit
// count / day count needs) — right before printing, each is measured and
// uniformly scaled to fill its landscape page, instead of being stranded
// small in one corner (few habits) or overflowing it (many). CSS alone
// can't do this: a scale-to-fit needs the content's actual rendered size,
// which only exists after layout. Uses `zoom`, not `transform: scale()` —
// transform is paint-only and leaves the original (pre-scale) box for
// pagination, so a shrunk-to-look-smaller table still split across two
// printed pages and a shrunk wheel still clipped at the page edge. `zoom`
// actually resizes the layout box, so the browser paginates and fits the
// *scaled* size.
//
// Always mounted off-screen (not display:none) rather than only appearing
// for print — Recharts' ResponsiveContainer measures its parent via
// ResizeObserver at mount time, which doesn't reliably re-fire in the
// instant between opening the print dialog and the browser's print
// snapshot, so a display:none-until-print chart can render blank. Being
// mounted with a real off-screen width means every chart already has real
// pixels to report before Export is ever clicked; print CSS just moves it
// into the page instead of triggering its first layout.
export function HabitPrintExport({ habits, month, counts, metadata }: HabitPrintExportProps) {
  const wheelRef = useRef<HTMLDivElement | null>(null);
  const gridRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    // The wheel is roughly as tall as it is wide, close enough to the
    // landscape page's own proportions that a uniform scale-to-fit,
    // centered in the box, fills it with no meaningful leftover space.
    function scaleWheel() {
      const el = wheelRef.current;
      const box = el?.parentElement;
      if (!el || !box) return;
      el.style.zoom = "";
      // Fit against fill-body's own box, not a hardcoded page size — it's
      // a flex sibling of the <h2> heading inside the fixed-height
      // section, so its real height already excludes whatever the
      // heading took, and its width already reflects the printer's
      // actual page size (Letter/A4) rather than a guessed constant.
      const { width: boxWidth, height: boxHeight } = box.getBoundingClientRect();
      const { width, height } = el.getBoundingClientRect();
      if (width === 0 || height === 0 || boxWidth === 0 || boxHeight === 0) return;
      el.style.zoom = String(Math.min(boxWidth / width, boxHeight / height, MAX_SCALE));
    }

    // The grid table isn't wheel-shaped — it's a fixed ~30 day-column width
    // with a height that only depends on habit count, so it's rarely the
    // same proportions as the landscape box. `zoom` can only scale both
    // axes together, so whichever axis is further from the box's aspect
    // ratio drags the other one along and strands it (a short table left
    // small at the top, or a tall table's already-narrower width shrunk
    // even further). Adjusting row height first — grown for a short table,
    // shrunk for a tall one — brings the table's own proportions to the
    // box's before zoom ever runs, so zoom only has to make a small final
    // correction instead of carrying the whole width-vs-height gap.
    function scaleGrid() {
      const el = gridRef.current;
      const box = el?.parentElement;
      const rows = habits.length;
      if (!el || !box || !rows) return;
      el.style.zoom = "";
      el.style.removeProperty("--habit-print-row-height");
      const headerHeight = el.querySelector("thead")?.getBoundingClientRect().height;
      const { width: boxWidth, height: boxHeight } = box.getBoundingClientRect();
      const { width, height } = el.getBoundingClientRect();
      if (!headerHeight || width === 0 || height === 0 || boxWidth === 0 || boxHeight === 0) return;

      // Solve for the row height that makes (header + rows * rowHeight),
      // once zoomed by width to fill the box, equal boxHeight exactly —
      // not a ratio of the *current* total height, which double-counts
      // the header (it doesn't grow with the rows) and misses the target
      // on a short table. Floored, not capped: filling the page is the
      // point, and an overshoot on a 1-habit table still isn't cropped —
      // the zoom step below shrinks it to fit either way. The floor only
      // exists so a long habit list doesn't shrink rows past legibility.
      const targetHeight = (boxHeight / boxWidth) * width;
      const rowHeight = Math.max((targetHeight - headerHeight) / rows, MIN_ROW_HEIGHT_PX);
      el.style.setProperty("--habit-print-row-height", `${rowHeight}px`);

      const grown = el.getBoundingClientRect();
      el.style.zoom = String(Math.min(boxWidth / grown.width, boxHeight / grown.height, MAX_SCALE));
    }

    function scaleToFit() {
      scaleWheel();
      scaleGrid();
    }
    window.addEventListener("beforeprint", scaleToFit);
    return () => window.removeEventListener("beforeprint", scaleToFit);
  }, []);

  return (
    <div
      aria-hidden
      // eslint-disable-next-line no-restricted-syntax -- off-screen print-only measuring box, never seen on any real viewport
      className="fixed left-[-9999px] top-0 w-[720px] print:static print:left-auto print:top-auto print:w-full"
    >
      {/* Wheel and table are the two wide layouts — each gets its own
          landscape page (see the named @page rule in journal-theme.css)
          and its content is scaled (see scaleToFit above) to fill it. The
          three chart cards stay on the default portrait page, already
          full-width there. */}
      <section className="habit-print-page habit-print-landscape habit-print-fill">
        <h2 className="habits-journal-headline mb-4 text-lg font-semibold">{monthLabel(month)} — Habit Wheel</h2>
        <div className="habit-print-fill-body">
          <div ref={wheelRef}>
            <DailyHabitWheel
              counts={counts}
              editable={false}
              habits={habits}
              month={month}
              onColorChange={noop}
              onDelete={noop}
              onToggle={noop}
            />
          </div>
        </div>
      </section>
      <section className="habit-print-page habit-print-landscape habit-print-fill">
        <h2 className="habits-journal-headline mb-4 text-lg font-semibold">{monthLabel(month)} — Habit Grid</h2>
        <div className="habit-print-fill-body">
          <div ref={gridRef}>
            <HabitGrid
              counts={counts}
              habits={habits}
              metadata={metadata}
              month={month}
              onCustomize={noopAsync}
              onDelete={noop}
              onSaveMetadata={noopAsync}
              onToggle={noop}
            />
          </div>
        </div>
      </section>
      <section className="habit-print-page">
        <SleepQualityCard habits={habits} metadata={metadata} month={month} />
      </section>
      <section className="habit-print-page">
        <GymPerformanceCard habits={habits} metadata={metadata} month={month} />
      </section>
      <section>
        <ReadingProgressCard habits={habits} metadata={metadata} month={month} />
      </section>
    </div>
  );
}
