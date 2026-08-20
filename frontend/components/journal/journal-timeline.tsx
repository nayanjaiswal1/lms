"use client";

import { MotionConfig, motion, type Variants } from "framer-motion";
import { GitMerge, NotebookPen } from "lucide-react";

import { Button } from "@/components/ui/button";
import { JournalEntryCard } from "@/components/journal/journal-entry-card";
import { useJournalMerge } from "@/components/journal/use-journal-merge";
import type { JournalEntry } from "@/lib/server/journal";

// Matches globals.css --duration-slow / --ease-smooth so the mount cascade
// reads as the same motion language as the rest of the app. Two-level
// stagger (group, then its cards) via variant propagation — only the top
// <ol> declares initial/animate, everything below inherits.
const EASE_SMOOTH = [0.22, 1, 0.36, 1] as const;

const listVariants: Variants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.08 } },
};

const groupVariants: Variants = {
  hidden: { opacity: 0, y: 12 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.35, ease: EASE_SMOOTH, staggerChildren: 0.05, delayChildren: 0.1 },
  },
};

const cardVariants: Variants = {
  hidden: { opacity: 0, y: 8, scale: 0.98 },
  visible: { opacity: 1, y: 0, scale: 1, transition: { duration: 0.3, ease: EASE_SMOOTH } },
};

interface JournalTimelineProps {
  entries: JournalEntry[];
}

const DATE_FORMAT: Intl.DateTimeFormatOptions = { month: "short", day: "numeric" };

function formatShortDate(date: string): string {
  return new Date(`${date}T00:00:00`).toLocaleDateString(undefined, DATE_FORMAT);
}

interface DateGroup {
  date: string;
  entries: JournalEntry[];
}

// entries arrive newest-day-first from the API, so entries sharing a date
// are already adjacent — one sequential pass groups them without a Map.
function groupByDate(entries: JournalEntry[]): DateGroup[] {
  const groups: DateGroup[] = [];
  for (const entry of entries) {
    const last = groups[groups.length - 1];
    if (last && last.date === entry.entry_date) last.entries.push(entry);
    else groups.push({ date: entry.entry_date, entries: [entry] });
  }
  return groups;
}

export function JournalTimeline({ entries }: JournalTimelineProps) {
  const groups = groupByDate(entries);
  const merge = useJournalMerge(entries);

  return (
    <MotionConfig reducedMotion="user">
      <motion.ol
        animate="visible"
        className="relative flex flex-col gap-8 py-2 before:absolute before:inset-y-0 before:left-[1.125rem] before:w-0.5 before:-translate-x-1/2 before:bg-primary/20"
        initial="hidden"
        variants={listVariants}
      >
        {groups.map((group) => {
          const mergeableCount = group.entries.filter((e) => e.source === "journal").length;
          const inMergeMode = merge.mergeDay === group.date;
          return (
            <motion.li
              className="relative grid grid-cols-[2.25rem_1fr] items-start gap-4"
              key={group.date}
              variants={groupVariants}
            >
              <span className="z-10 col-start-1 flex size-9 items-center justify-center rounded-full border-4 border-background bg-primary text-primary-foreground shadow-sm">
                <NotebookPen aria-hidden className="h-4 w-4" />
              </span>
              <div className="col-start-2 flex min-w-0 flex-col gap-2">
                <div className="flex items-center justify-between gap-2">
                  <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                    {formatShortDate(group.date)}
                  </span>
                  {mergeableCount >= 2 && (
                    <Button
                      className="h-7 gap-1 text-xs text-muted-foreground"
                      size="sm"
                      variant="ghost"
                      onClick={() => merge.toggleMergeDay(group.date)}
                    >
                      <GitMerge aria-hidden className="size-3.5" />
                      {inMergeMode ? "Cancel merge" : "Merge cards"}
                    </Button>
                  )}
                </div>
                <div className="flex flex-wrap gap-3">
                  {group.entries.map((entry) => (
                    <motion.div key={entry.id} variants={cardVariants}>
                      <JournalEntryCard
                        entry={entry}
                        selectable={inMergeMode && entry.source === "journal"}
                        selected={merge.selectedIds.includes(entry.id)}
                        onToggleSelect={() => merge.toggleSelect(entry.id)}
                      />
                    </motion.div>
                  ))}
                </div>
              </div>
            </motion.li>
          );
        })}
      </motion.ol>

      {merge.selectedIds.length === 2 && (
        <div className="fixed inset-x-4 bottom-4 z-modal flex justify-center sm:inset-x-auto sm:right-4 sm:left-auto">
          <div className="card-base flex items-center gap-3 border border-primary/20 p-3 shadow-raised">
            <span className="text-sm text-foreground">Merge these 2 entries into one?</span>
            <Button disabled={merge.isPending} size="sm" onClick={merge.confirmMerge}>
              {merge.isPending ? "Merging…" : "Merge"}
            </Button>
            <Button size="sm" variant="ghost" onClick={merge.cancel}>
              Cancel
            </Button>
          </div>
        </div>
      )}
    </MotionConfig>
  );
}
