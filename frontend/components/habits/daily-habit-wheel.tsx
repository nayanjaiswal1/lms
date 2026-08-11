"use client";

import { useEffect, useState } from "react";
import { CalendarDays, CalendarRange, Sun, X } from "lucide-react";
import { polarToCartesian, ringArcPath, wedgePath } from "@/components/habits/wedge-path";
import { Button } from "@/components/ui/button";
import type { HabitColorValue } from "@/lib/constants";
import { dateAt, daysInMonth, firstOfMonth, weekDayRange, weekdayOfDay, weekStarts } from "@/lib/habits/dates";
import type { Habit } from "@/lib/server/habits";
import { cn } from "@/lib/utils";
import { HABIT_FILL_CLASS, HABIT_SWATCH_CLASS, HabitColorPicker } from "@/components/habits/habit-color-picker";
import { HabitIcon } from "@/components/habits/habit-icon";
import { HABIT_TYPE_ICON, hasEntryForm } from "@/lib/habits/type-schemas";
import styles from "./daily-habit-wheel.module.css";

// Rings are ordered inner-to-outer by cadence — monthly and weekly nearest
// the hole, daily as the outermost ring.
export const CADENCE_ORDER: Record<Habit["cadence"], number> = { monthly: 0, weekly: 1, daily: 2 };
// Same glyph the add-habit cadence picker uses, repeated on each ring's own
// label so a row reads as weekly/monthly at a glance instead of only
// differing by how wide its wedges are.
export const CADENCE_ICON: Record<Habit["cadence"], typeof Sun> = { daily: Sun, weekly: CalendarDays, monthly: CalendarRange };

export interface WheelCell {
  period: string;
  startDay: number; // 1-indexed, inclusive
  endDay: number; // 1-indexed, inclusive
  label: string;
  // False only for a "specific weekdays" habit's off days — rendered as a
  // dim, unclickable filler cell so the ring still reads as a full circle.
  interactive: boolean;
}

// Every ring shares the same day-of-month angular grid — a weekly or
// monthly habit just merges several day-cells into one wider wedge instead
// of getting its own angle scale, so its edges always land exactly on a day
// spoke and week 1 always starts under day 1 in the notch.
// Shared by the grid view (habit-grid.tsx) — same cadence-to-cells mapping,
// just rendered as table columns with colSpan instead of SVG wedges.
export function cellsForHabit(habit: Habit, month: string, days: number): WheelCell[] {
  if (habit.cadence === "weekly" && habit.weekdays.length > 0) {
    // "Specific weekdays" mode: one cell per calendar day, same grain as a
    // daily habit, but only the chosen weekdays are checkable.
    const scheduled = new Set(habit.weekdays);
    return Array.from({ length: days }, (_, i) => {
      const day = i + 1;
      return {
        period: dateAt(month, day),
        startDay: day,
        endDay: day,
        label: `day ${day}`,
        interactive: scheduled.has(weekdayOfDay(month, day)),
      };
    });
  }
  if (habit.cadence === "weekly") {
    return weekStarts(month).map((week, i) => {
      const [startDay, endDay] = weekDayRange(week, month, days);
      return { period: week, startDay, endDay, label: `week ${i + 1}`, interactive: true };
    });
  }
  if (habit.cadence === "monthly") {
    return [{ period: firstOfMonth(month), startDay: 1, endDay: days, label: "this month", interactive: true }];
  }
  return Array.from({ length: days }, (_, i) => {
    const day = i + 1;
    return { period: dateAt(month, day), startDay: day, endDay: day, label: `day ${day}`, interactive: true };
  });
}

// The canvas grows with the number of habits instead of squeezing them into
// a fixed box — a fixed size forced ring thickness to shrink below a
// readable floor once habit count grew, and clipped everything past it.
// Ring thickness stays constant; radius (and everything derived from it)
// grows outward instead.
// Scaled up ~80% from the original calibration pass (was 46/22) — same
// hole:ring-thickness ratio (~2.1), just a bigger wheel overall.
const HOLE_RADIUS = 83;
const RING_THICKNESS = 40;
const LABEL_AREA_WIDTH = 300; // reserved on the left for leader lines + labels
const RIM_MARGIN = 34; // room for day-number labels outside the outer ring
// The wheel isn't a full circle — a pie-slice notch is left open, same as the
// reference planner page, and each habit's name-label is a leader line that
// starts exactly where that ring's arc stops at the notch (so it visually
// connects to its own ring) and runs out to the label text, rather than a
// detached sidebar list. Angle 0 = 12 o'clock, increasing clockwise (see
// polarToCartesian). Measured off the reference: ~80° wide, centered at 300°
// (rotated toward upper-left, not symmetric due-west) — that asymmetry is
// why the reference's bottom-left fan is visibly larger than a symmetric
// notch would produce.
const GAP_ANGLE = 80;
const GAP_CENTER = 300;
const SWEEP_START = GAP_CENTER + GAP_ANGLE / 2; // upper edge of the notch — where labels attach, bordering the top fan
const SWEEP_ANGLE = 360 - GAP_ANGLE;
const LABEL_ANCHOR_ANGLE = SWEEP_START;
// Fixed instead of scaled to each habit's name length — a per-name width
// made every row's leader line a different total length (a 1-char name's
// line stopped right after the dot, a long name's ran much farther), which
// broke the evenly-stepped cascade down the label column. Truncation
// (`truncate` on the name span) already handles names that don't fit.
const LABEL_WIDTH = 200;
// Grid-line stagger grows with habit count × days in the month, so an
// uncapped per-line delay made the draw-in reveal take several seconds on a
// board with many habits. Capping the delay means later lines bunch up and
// draw together past this point instead of trickling in one at a time.
const MAX_STAGGER_MS = 400;
// Month navigation remounts this component (see the `key={month}` on
// HabitBoard's parent, needed so stale per-month state doesn't leak
// across months) — without this flag every month click replayed the full
// draw-in reveal instead of only playing it once per page load.
let hasPlayedIntro = false;

// Grid ink — thin foreground-tinted lines on paper, like a printed polar
// graph rather than a filled progress donut. Cell fill (fill-card / fill-primary)
// carries no stroke of its own; every line is drawn once by this overlay so
// ring and day boundaries stay a uniform width instead of doubling where two
// wedges share an edge.
// /25 read as barely-there against the journal paper's own texture — bumped
// for legibility now that the wheel sits on that background everywhere, not
// just a plain card.
const GRID_LINE = "stroke-foreground/35";
// Ring boundaries are the wheel's main structural lines (habit-row dividers) —
// given the brand's primary (amber/"fire, progress") tint instead of plain
// foreground gray, so they read as an intentional part of the progress wheel
// rather than a neutral grid line, and stay visible over a "done" wedge fill.
const RING_LINE = "stroke-primary/70";
// Degrees each wedge is widened by on both radial edges so it overlaps its
// neighbor instead of butting exactly against it — see the wedgePath call below.
const SEAM_OVERLAP = 0.25;

interface DailyHabitWheelProps {
  habits: Habit[];
  month: string;
  counts: Map<string, number>;
  // Wheel defaults to a read-only progress display — checking off habits,
  // recoloring, and deleting are only wired up while this is true.
  editable: boolean;
  onColorChange: (habitId: string, color: HabitColorValue) => void;
  onDelete: (habitId: string) => void;
  onToggle: (habitId: string, period: string, done: boolean) => void;
}

export function DailyHabitWheel({
  habits,
  month,
  counts,
  editable,
  onColorChange,
  onDelete,
  onToggle,
}: DailyHabitWheelProps) {
  const [skipIntro] = useState(hasPlayedIntro);
  useEffect(() => {
    hasPlayedIntro = true;
  }, []);
  const days = daysInMonth(month);
  const dayAngle = SWEEP_ANGLE / days;
  const orderedHabits = [...habits].sort((a, b) => CADENCE_ORDER[a.cadence] - CADENCE_ORDER[b.cadence]);
  // An empty wheel still draws one guide ring (like the printed template) so
  // the grid is visible before the first habit exists, not a blank circle.
  const ringCount = Math.max(orderedHabits.length, 1);
  const ringThickness = RING_THICKNESS;
  const gridOuterRadius = HOLE_RADIUS + ringCount * ringThickness;
  const CENTER_X = LABEL_AREA_WIDTH + gridOuterRadius;
  const CENTER_Y = gridOuterRadius + RIM_MARGIN;
  // Mirrors LABEL_AREA_WIDTH on the right (rather than the much narrower
  // RIM_MARGIN) so CENTER_X lands exactly at SIZE_W/2 — a plain `mx-auto`
  // then centers the circle itself, not just the box. A negative-margin
  // trick to recenter an asymmetric box instead clipped the label/line
  // column off-screen on any viewport narrower than the box, since content
  // shifted past a scroll container's start edge isn't reachable by
  // scrolling. The added right-side space is blank canvas, never clipping
  // real content — RIM_MARGIN alone still easily covers the day-number labels.
  const SIZE_W = CENTER_X + gridOuterRadius + LABEL_AREA_WIDTH;
  const SIZE_H = CENTER_Y + gridOuterRadius + RIM_MARGIN;
  let lineIndex = 0;
  // Short connector tick out of the ring, not a long run — scales with the
  // wheel's own radius instead of a flat pixel value so a small wheel
  // doesn't strand it disproportionately far from a tiny circle, capped
  // well below the old fixed length so it stays snug against every ring.
  const labelLineLength = Math.min(28, gridOuterRadius * 0.35);

  return (
    <section>
      <div className="overflow-x-auto">
        {/* SIZE_W is built symmetric around CENTER_X (see above), so a plain
            mx-auto centers the circle itself, not just an off-center box. */}
        <svg className="mx-auto block" height={SIZE_H} viewBox={`0 0 ${SIZE_W} ${SIZE_H}`} width={SIZE_W}>
          {/* Whole wheel nudged 2° clockwise — a cosmetic rotation on top of
              the calibrated geometry, not a change to the notch/day angles themselves. */}
          <g transform={`rotate(2 ${CENTER_X} ${CENTER_Y})`}>
          {orderedHabits.map((habit, ringIndex) => {
            const innerR = HOLE_RADIUS + ringIndex * ringThickness;
            const outerR = innerR + ringThickness;
            // Only an "any N times a week" habit (weekly, no fixed weekdays,
            // target above 1) tracks a count above 1 — every other cadence
            // and mode is a plain done/not-done check.
            const target = habit.cadence === "weekly" && habit.weekdays.length === 0 ? habit.target_count : 1;
            const showCount = target > 1;
            return cellsForHabit(habit, month, days).map((cell) => {
              const count = counts.get(`${habit.id}:${cell.period}`) ?? 0;
              const done = count >= target;
              const startAngle = SWEEP_START + (cell.startDay - 1) * dayAngle;
              const endAngle = SWEEP_START + cell.endDay * dayAngle;
              const midR = (innerR + outerR) / 2;
              const midAngle = (startAngle + endAngle) / 2;
              const countPos = showCount ? polarToCartesian(CENTER_X, CENTER_Y, midR, midAngle) : null;
              const clickable = cell.interactive && editable;
              return (
                <g key={`${habit.id}-${cell.period}`}>
                  <path
                    aria-label={
                      !cell.interactive
                        ? `${habit.name}, ${cell.label}, not scheduled`
                        : showCount
                          ? `${habit.name}, ${cell.label}, ${count} of ${target}`
                          : `${habit.name}, ${cell.label}, ${done ? "done" : "not done"}`
                    }
                    className={cn(
                      !skipIntro && styles.fadeIn,
                      // outline-none + a shape-following stroke on focus-visible instead of
                      // the default focus ring — box-shadow/outline both draw a rectangle
                      // around an SVG path's bounding box, not around the wedge itself.
                      "stroke-transparent stroke-2 outline-none transition-colors duration-fast",
                      !cell.interactive
                        ? "fill-muted/20"
                        : cn(
                            // Hover reads as an affordance ("this is a data point") even
                            // in read-only mode — only the click/keyboard handling below
                            // is gated behind `clickable`. A "done" wedge already carries
                            // its habit color, so hover brightens it instead of swapping
                            // to the accent tint used for a "not done" cell.
                            done ? "hover:brightness-110" : "hover:fill-accent",
                            clickable && "cursor-pointer focus-visible:stroke-ring",
                            done ? HABIT_FILL_CLASS[habit.color] : "fill-card",
                          ),
                    )}
                    d={wedgePath(
                      CENTER_X,
                      CENTER_Y,
                      innerR,
                      outerR,
                      // Widened by SEAM_OVERLAP on both sides so adjacent wedges
                      // overlap by a hair instead of butting edge to edge —
                      // anti-aliasing on an exact shared boundary otherwise lets
                      // the page background bleed through as a dashed seam, most
                      // visible when both wedges are the same "done" color and
                      // should read as one unbroken arc. shapeRendering=crispEdges
                      // was tried first but stair-steps unevenly along a curved
                      // edge, which reads as the same dashed seam it's meant to fix.
                      startAngle - SEAM_OVERLAP,
                      endAngle + SEAM_OVERLAP,
                      // Only a single-day cell gets the flat-chord edge — a merged
                      // multi-day cell (a week, or the whole month) spans far more
                      // than the notch-adjacent sliver that edge treatment was
                      // built for, and a straight chord across tens of degrees
                      // cuts a visible triangle out of the wedge instead of a curve.
                      cell.startDay === 1 && cell.startDay === cell.endDay,
                    )}
                    role={clickable ? "button" : undefined}
                    onClick={clickable ? () => onToggle(habit.id, cell.period, done) : undefined}
                    onKeyDown={
                      clickable
                        ? (e) => {
                            if (e.key === "Enter" || e.key === " ") {
                              e.preventDefault();
                              onToggle(habit.id, cell.period, done);
                            }
                          }
                        : undefined
                    }
                    tabIndex={clickable ? 0 : -1}
                    // eslint-disable-next-line no-restricted-syntax -- staggering the draw-on-load reveal needs a per-element delay
                    style={{ animationDelay: "550ms" }}
                  />
                  {countPos && (
                    <text
                      className={cn(
                        "pointer-events-none select-none fill-foreground/70 text-[8px]",
                        !skipIntro && styles.fadeIn,
                      )}
                      dominantBaseline="middle"
                      textAnchor="middle"
                      x={countPos.x}
                      y={countPos.y}
                      // eslint-disable-next-line no-restricted-syntax -- matches the wedge's own staggered reveal delay
                      style={{ animationDelay: "550ms" }}
                    >
                      {count}/{target}
                    </text>
                  )}
                </g>
              );
            });
          })}

          {/* Grid overlay — ring boundaries (habit rows), open arcs so the notch stays clear */}
          <g fill="none">
            {Array.from({ length: ringCount + 1 }, (_, i) => {
              const delay = Math.min(lineIndex++ * 35, MAX_STAGGER_MS);
              return (
                <path
                  className={cn(RING_LINE, !skipIntro && styles.gridLine, "pointer-events-none")}
                  d={ringArcPath(CENTER_X, CENTER_Y, HOLE_RADIUS + i * ringThickness, SWEEP_START, SWEEP_START + SWEEP_ANGLE, dayAngle)}
                  key={`ring-${i}`}
                  strokeWidth={1}
                  pathLength={1}
                  // eslint-disable-next-line no-restricted-syntax -- staggered stroke-draw reveal needs a per-element delay
                  style={{ animationDelay: `${delay}ms` }}
                />
              );
            })}
          </g>

          {/* Grid overlay — cell boundaries (spokes), scoped to each ring's own band.
              Drawing every day-tick the full HOLE_RADIUS-to-rim length made the weekly
              and monthly rings visually look sliced into all 31 days too, even though
              their wedges are merged — each ring now only gets ticks at its own cell
              edges (week edges for a weekly ring, none but its outer edge for monthly). */}
          <g>
            {orderedHabits.map((habit, ringIndex) => {
              const innerR = HOLE_RADIUS + ringIndex * ringThickness;
              const outerR = innerR + ringThickness;
              const cells = cellsForHabit(habit, month, days);
              const target = habit.cadence === "weekly" && habit.weekdays.length === 0 ? habit.target_count : 1;
              const cellDone = (cell: WheelCell) => (counts.get(`${habit.id}:${cell.period}`) ?? 0) >= target;
              const boundaryDays = [cells[0].startDay - 1, ...cells.map((cell) => cell.endDay)];
              return boundaryDays.map((boundaryDay, i) => {
                // Skip the seam between two consecutive done cells — a run of
                // checked-off days reads as one unbroken block of color instead
                // of being cut into strips by the ordinary day-tick grid. The
                // ring's own outer start/end edges (i===0 or the last boundary)
                // always draw — those are the ring's real boundary, not a seam.
                const isInternalSeam = i > 0 && i < boundaryDays.length - 1;
                if (isInternalSeam && cellDone(cells[i - 1]) && cellDone(cells[i])) return null;
                const angle = SWEEP_START + boundaryDay * dayAngle;
                const inner = polarToCartesian(CENTER_X, CENTER_Y, innerR, angle);
                const outer = polarToCartesian(CENTER_X, CENTER_Y, outerR, angle);
                const delay = Math.min(lineIndex++ * 8, MAX_STAGGER_MS);
                return (
                  <line
                    className={cn(GRID_LINE, !skipIntro && styles.gridLine, "pointer-events-none")}
                    key={`spoke-${habit.id}-${boundaryDay}`}
                    pathLength={1}
                    strokeWidth={1}
                    // eslint-disable-next-line no-restricted-syntax -- staggered stroke-draw reveal needs a per-element delay
                    style={{ animationDelay: `${delay}ms` }}
                    x1={inner.x}
                    x2={outer.x}
                    y1={inner.y}
                    y2={outer.y}
                  />
                );
              });
            })}
          </g>

          {/* Leader lines — one per ring, anchored exactly where that ring's arc meets the notch */}
          <g>
            {orderedHabits.map((habit, ringIndex) => {
              // Same radius as this ring's own boundary arc (the "ring-{i}"
              // path above) — anchoring at the ring's mid-band instead left a
              // visible gap, since no grid line is ever drawn there.
              const boundaryR = HOLE_RADIUS + ringIndex * ringThickness;
              const anchor = polarToCartesian(CENTER_X, CENTER_Y, boundaryR, LABEL_ANCHOR_ANGLE);
              const lineEndX = anchor.x - labelLineLength;
              const labelStartX = lineEndX - LABEL_WIDTH;
              const delay = Math.min(lineIndex++ * 35, MAX_STAGGER_MS);
              const wheelFallbackIcon = hasEntryForm(habit) ? HABIT_TYPE_ICON[habit.type] : CADENCE_ICON[habit.cadence];
              return (
                <g key={habit.id}>
                  {/* Runs the full length under the label too, not just the gap
                      before it — ruled paper doesn't stop where the word starts. */}
                  <line
                    className={cn(GRID_LINE, !skipIntro && styles.gridLine, "pointer-events-none")}
                    pathLength={1}
                    strokeWidth={1}
                    // eslint-disable-next-line no-restricted-syntax -- staggered stroke-draw reveal needs a per-element delay
                    style={{ animationDelay: `${delay}ms` }}
                    x1={anchor.x}
                    x2={labelStartX}
                    y1={anchor.y}
                    y2={anchor.y}
                  />
                  {/* Text sits directly on the line, like handwriting on ruled paper —
                      not floating in a label box above it. Delete button only
                      shows on hover/focus so it doesn't clutter every line. */}
                  <foreignObject
                    className={cn(!skipIntro && styles.fadeIn)}
                    height={40}
                    // eslint-disable-next-line no-restricted-syntax -- staggered reveal needs a per-element delay, position is computed from wheel geometry, and overflow:visible lets the delete button's touch-target padding extend past this box on hover instead of being clipped
                    style={{ animationDelay: "650ms", overflow: "visible" }}
                    width={LABEL_WIDTH}
                    x={labelStartX}
                    y={anchor.y - 40}
                  >
                    {/* justify-end: a short name in a flex-1 span left its glyph
                        stranded far from the line/ring with a wide dead gap after
                        it — anchoring the whole row (dot+icon+name) to the box's
                        line-side edge instead keeps the word snug against the
                        line regardless of how short the name is. */}
                    <div className="group relative flex h-full items-end justify-end gap-1">
                      {/* translate-y-4: same fix as the delete button below — the
                          touch-target's 44px hit box is taller than the text-xs
                          label line, so items-end alone centers the visible dot
                          well above the text instead of beside it. */}
                      <span className="translate-y-4 self-end">
                        {editable ? (
                          <HabitColorPicker
                            color={habit.color}
                            habitName={habit.name}
                            onChange={(color) => onColorChange(habit.id, color)}
                          />
                        ) : (
                          <span aria-hidden className={cn("size-3 rounded-full", HABIT_SWATCH_CLASS[habit.color])} />
                        )}
                      </span>
                      <HabitIcon className="mb-0.5 size-3 shrink-0 self-end text-muted-foreground" fallback={wheelFallbackIcon} icon={habit.icon} />
                      <span className="max-w-[140px] truncate pb-0.5 pr-5 text-xs leading-none">{habit.name}</span>
                      {editable && (
                        <Button
                          aria-label={`Delete ${habit.name}`}
                          // -bottom-4: touch-target's 44px hit box is taller than the
                          // text-xs/leading-none label line, so bottom-0 centered the
                          // icon well above the text instead of beside it. Shifting the
                          // box down by (44 - text line height) / 2-ish re-centers the
                          // visible icon on the label's own baseline; the extra hit-area
                          // below is empty space under the row, not clipped (see overflow:visible above).
                          className="touch-target absolute -bottom-4 right-0 opacity-0 transition-opacity duration-fast hover:bg-transparent group-hover:opacity-100 focus-visible:opacity-100"
                          size="icon"
                          variant="ghost"
                          onClick={() => onDelete(habit.id)}
                        >
                          <X aria-hidden className="size-3.5" />
                        </Button>
                      )}
                    </div>
                  </foreignObject>
                </g>
              );
            })}
          </g>

          <g className={cn(!skipIntro && styles.fadeIn)} style={{ animationDelay: "650ms" } as React.CSSProperties}>
            {Array.from({ length: days }, (_, i) => {
              const day = i + 1;
              const angle = SWEEP_START + i * dayAngle + dayAngle / 2;
              const { x, y } = polarToCartesian(CENTER_X, CENTER_Y, gridOuterRadius + 16, angle);
              return (
                <text className="fill-foreground/70 text-[10px]" dominantBaseline="middle" key={`label-${day}`} textAnchor="middle" x={x} y={y}>
                  {day}
                </text>
              );
            })}
          </g>

          {orderedHabits.length === 0 && (
            <text className="fill-muted-foreground text-[11px]" textAnchor="middle" x={CENTER_X + 20} y={CENTER_Y}>
              <tspan dy="-0.3em" x={CENTER_X + 20}>Add a habit</tspan>
              <tspan dy="1.2em" x={CENTER_X + 20}>to start</tspan>
            </text>
          )}
          </g>
        </svg>
      </div>
    </section>
  );
}
