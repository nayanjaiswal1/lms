"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

interface QuickCreateSlotProps {
  defaultStart: Date;
  defaultEnd: Date;
  onCreate: (title: string, start: Date, end: Date, isTask: boolean) => void;
  onCancel: () => void;
}

function toTimeInputValue(date: Date): string {
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

// Combines base's calendar day with a "HH:mm" time-of-day string.
function withTimeOfDay(base: Date, timeValue: string): Date {
  const [hours, minutes] = timeValue.split(":").map(Number);
  const next = new Date(base);
  next.setHours(hours, minutes, 0, 0);
  return next;
}

// Rendered inside a <PopoverContent>, which already supplies the card
// chrome (border/shadow/padding) — this is just the field stack.
export function QuickCreateSlot({ defaultStart, defaultEnd, onCreate, onCancel }: QuickCreateSlotProps) {
  const [title, setTitle] = React.useState("");
  const [isTask, setIsTask] = React.useState(false);
  const [startTime, setStartTime] = React.useState(toTimeInputValue(defaultStart));
  const [endTime, setEndTime] = React.useState(toTimeInputValue(defaultEnd));

  function submit() {
    if (!title.trim()) return;
    onCreate(title.trim(), withTimeOfDay(defaultStart, startTime), withTimeOfDay(defaultStart, endTime), isTask);
  }

  return (
    <div className="flex flex-col gap-3">
      <div aria-label="Event or task" className="flex gap-1.5" role="radiogroup">
        <Button
          aria-pressed={!isTask}
          size="sm"
          type="button"
          variant={isTask ? "outline" : "secondary"}
          onClick={() => setIsTask(false)}
        >
          Event
        </Button>
        <Button
          aria-pressed={isTask}
          size="sm"
          type="button"
          variant={isTask ? "secondary" : "outline"}
          onClick={() => setIsTask(true)}
        >
          Task
        </Button>
      </div>
      <Input
        // eslint-disable-next-line jsx-a11y/no-autofocus -- the popover only opens after an explicit click, so autofocus is expected here rather than a distraction
        autoFocus
        aria-label={isTask ? "New task title" : "New event title"}
        placeholder={isTask ? "Task title…" : "Event title…"}
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            submit();
          }
        }}
      />
      {!isTask && (
        <div className="flex items-center gap-2">
          <Input aria-label="Start time" className="min-w-0" type="time" value={startTime} onChange={(e) => setStartTime(e.target.value)} />
          <span className="shrink-0 text-sm text-muted-foreground">to</span>
          <Input aria-label="End time" className="min-w-0" type="time" value={endTime} onChange={(e) => setEndTime(e.target.value)} />
        </div>
      )}
      {isTask && (
        <Input aria-label="Due time" className="min-w-0" type="time" value={startTime} onChange={(e) => setStartTime(e.target.value)} />
      )}
      <div className="flex justify-end gap-2">
        <Button size="sm" type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button size="sm" type="button" onClick={submit}>
          Create
        </Button>
      </div>
    </div>
  );
}
