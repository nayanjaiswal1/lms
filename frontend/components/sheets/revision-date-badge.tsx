"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { updateProgressRevisionAction } from "@/lib/sheets/actions";

interface RevisionDateBadgeProps {
  topicTag: string;
  revisionAt: string;
  isDue?: boolean;
  disabled?: boolean;
  onAdvance?: () => void;
}

function toDateInputValue(iso: string): string {
  return iso.slice(0, 10);
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function RevisionDateBadge({ topicTag, revisionAt, isDue, disabled, onAdvance }: RevisionDateBadgeProps) {
  const [date, setDate] = useState(() => toDateInputValue(revisionAt));

  async function save(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    e.stopPropagation();
    const result = await updateProgressRevisionAction(topicTag, new Date(date).toISOString());
    if (!result.ok) toast.error(result.error ?? "Couldn't update the revision date.");
  }

  // A due revision needs one action, not two — this same badge becomes the
  // "advance to next interval" click instead of sitting next to a separate
  // button. Manual date editing (the popover below) only applies once it's
  // no longer due.
  if (isDue && onAdvance) {
    return (
      <button
        aria-label="Due — click to mark this revision done and schedule the next one"
        className="inline-flex items-center border-0 p-0 text-xs font-medium tabular-nums text-primary hover:underline"
        disabled={disabled}
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onAdvance();
        }}
      >
        Revise {formatDate(revisionAt)}
      </button>
    );
  }

  return (
    <Popover>
      <PopoverTrigger asChild>
        <button
          className="hidden items-center border-0 p-0 text-xs tabular-nums text-muted-foreground hover:text-foreground hover:underline sm:inline-flex"
          type="button"
          onClick={(e) => e.stopPropagation()}
        >
          Revise {formatDate(revisionAt)}
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-56" onClick={(e) => e.stopPropagation()}>
        <form className="form-stack" onSubmit={save}>
          <label className="text-xs font-medium text-muted-foreground" htmlFor={`revision-date-${topicTag}`}>
            Revise on
          </label>
          <Input
            id={`revision-date-${topicTag}`}
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
          <Button size="sm" type="submit">
            Save
          </Button>
        </form>
      </PopoverContent>
    </Popover>
  );
}
