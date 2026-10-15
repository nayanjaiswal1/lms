"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { TimeBlockPresets } from "@/app/(app)/calendar/time-block-presets";
import { SegmentedControl } from "@/app/(app)/calendar/segmented-control";
import { toTimeInputValue, withTimeOfDay } from "@/app/(app)/calendar/calendar-math";
import { Clock, AlertCircle, CheckCircle2, Zap } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { CALENDAR_PRIORITY_OPTIONS } from "@/lib/calendar/types";
import type { CalendarEventPriority } from "@/lib/calendar/types";

interface EnhancedQuickCreateProps {
  defaultStart: Date;
  defaultEnd: Date;
  onCreate: (
    title: string,
    start: Date,
    end: Date,
    isTask: boolean,
    notes?: string,
    priority?: CalendarEventPriority,
  ) => void;
  onCancel: () => void;
}

const ENTRY_TYPE_OPTIONS = [
  { label: "Event", value: "event", icon: Zap },
  { label: "Task", value: "task", icon: CheckCircle2 },
] as const;

function addMinutesToDate(date: Date, minutes: number): Date {
  const result = new Date(date);
  result.setMinutes(result.getMinutes() + minutes);
  return result;
}

function calculateDurationMinutes(start: Date, end: Date): number {
  return Math.round((end.getTime() - start.getTime()) / (1000 * 60));
}

function formatDuration(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
}

export function EnhancedQuickCreate({ defaultStart, defaultEnd, onCreate, onCancel }: EnhancedQuickCreateProps) {
  const uid = React.useId();
  const [title, setTitle] = React.useState("");
  const [notes, setNotes] = React.useState("");
  const [isTask, setIsTask] = React.useState(false);
  const [priority, setPriority] = React.useState<CalendarEventPriority>("medium");
  const [startTime, setStartTime] = React.useState(toTimeInputValue(defaultStart));
  const [endTime, setEndTime] = React.useState(toTimeInputValue(defaultEnd));
  const [usePreset, setUsePreset] = React.useState(false);

  const calculatedStart = withTimeOfDay(defaultStart, startTime);
  const calculatedEnd = withTimeOfDay(defaultStart, endTime);
  const durationMinutes = calculateDurationMinutes(calculatedStart, calculatedEnd);
  const durationText = formatDuration(Math.max(durationMinutes, 15));

  function handlePresetSelect(minutes: number) {
    const newEnd = addMinutesToDate(calculatedStart, minutes);
    setEndTime(toTimeInputValue(newEnd));
    setUsePreset(true);
  }

  function submit() {
    if (!title.trim()) return;
    onCreate(
      title.trim(),
      calculatedStart,
      isTask ? calculatedStart : calculatedEnd,
      isTask,
      notes.trim() || undefined,
      isTask ? priority : undefined,
    );
  }

  const isValidDuration = durationMinutes > 0;

  return (
    <div className="flex flex-col gap-4">
      <div className="space-y-2">
        <div className="text-xs font-medium text-muted-foreground">Type</div>
        <SegmentedControl
          label="Event or task"
          options={ENTRY_TYPE_OPTIONS}
          value={isTask ? "task" : "event"}
          onChange={(v) => setIsTask(v === "task")}
        />
      </div>

      <div className="space-y-2">
        <label className="block text-xs font-medium text-muted-foreground" htmlFor={`${uid}-title`}>
          {isTask ? "Task title" : "Event title"}
        </label>
        <Input
          className="text-sm"
          id={`${uid}-title`}
          placeholder={isTask ? "Study JavaScript…" : "Team meeting…"}
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              submit();
            }
          }}
        />
      </div>

      {!isTask && (
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground" htmlFor={`${uid}-start`}>Start</label>
              <Input
                className="text-sm"
                id={`${uid}-start`}
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground" htmlFor={`${uid}-end`}>End</label>
              <Input
                className="text-sm"
                id={`${uid}-end`}
                type="time"
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
              />
            </div>
          </div>

          <div className="flex-between rounded-md bg-muted/50 px-3 py-2">
            <div className="flex items-center gap-2">
              <Clock aria-hidden className="h-4 w-4 text-muted-foreground" />
              <span className="text-sm font-medium">{durationText}</span>
            </div>
            {!isValidDuration && (
              <div className="flex items-center gap-1 text-xs text-destructive">
                <AlertCircle aria-hidden className="h-3.5 w-3.5" />
                Invalid
              </div>
            )}
          </div>

          {usePreset === false && <TimeBlockPresets onSelect={handlePresetSelect} />}
        </div>
      )}

      {isTask && (
        <div className="grid grid-cols-2 gap-2">
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground" htmlFor={`${uid}-due`}>Due time</label>
            <Input
              className="text-sm"
              id={`${uid}-due`}
              type="time"
              value={startTime}
              onChange={(e) => setStartTime(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground" htmlFor={`${uid}-priority`}>Priority</label>
            <Select value={priority} onValueChange={(v) => setPriority(v as CalendarEventPriority)}>
              <SelectTrigger aria-label="Task priority" className="text-sm" id={`${uid}-priority`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {CALENDAR_PRIORITY_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>
      )}

      <div className="space-y-2">
        <label className="text-xs font-medium text-muted-foreground" htmlFor={`${uid}-notes`}>Notes (optional)</label>
        <Textarea
          className="min-h-20 resize-none text-sm"
          id={`${uid}-notes`}
          placeholder="Add context, links, or details…"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
        />
      </div>

      <div className="flex justify-end gap-2 pt-2">
        <Button type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button disabled={!title.trim() || !isValidDuration} type="button" onClick={submit}>
          Create {isTask ? "Task" : "Event"}
        </Button>
      </div>
    </div>
  );
}
