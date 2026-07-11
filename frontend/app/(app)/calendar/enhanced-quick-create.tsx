"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { TimeBlockPresets } from "@/app/(app)/calendar/time-block-presets";
import { Badge } from "@/components/ui/badge";
import { Clock, AlertCircle, CheckCircle2, Zap } from "lucide-react";

interface EnhancedQuickCreateProps {
  defaultStart: Date;
  defaultEnd: Date;
  onCreate: (title: string, start: Date, end: Date, isTask: boolean, notes?: string) => void;
  onCancel: () => void;
}

function toTimeInputValue(date: Date): string {
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function addMinutesToDate(date: Date, minutes: number): Date {
  const result = new Date(date);
  result.setMinutes(result.getMinutes() + minutes);
  return result;
}

function withTimeOfDay(base: Date, timeValue: string): Date {
  const [hours, minutes] = timeValue.split(":").map(Number);
  const next = new Date(base);
  next.setHours(hours, minutes, 0, 0);
  return next;
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
  const [title, setTitle] = React.useState("");
  const [notes, setNotes] = React.useState("");
  const [isTask, setIsTask] = React.useState(false);
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
      notes.trim() || undefined
    );
  }

  const isValidDuration = durationMinutes > 0;

  return (
    <div className="flex flex-col gap-4">
      {/* Event type selector */}
      <div className="space-y-2">
        <div className="text-xs font-medium text-muted-foreground">Type</div>
        <div aria-label="Event or task" className="flex gap-2" role="radiogroup">
          <Button
            aria-pressed={!isTask}
            size="sm"
            type="button"
            variant={isTask ? "outline" : "default"}
            onClick={() => setIsTask(false)}
            className="flex-1"
          >
            <Zap className="mr-1.5 h-3.5 w-3.5" />
            Event
          </Button>
          <Button
            aria-pressed={isTask}
            size="sm"
            type="button"
            variant={isTask ? "default" : "outline"}
            onClick={() => setIsTask(true)}
            className="flex-1"
          >
            <CheckCircle2 className="mr-1.5 h-3.5 w-3.5" />
            Task
          </Button>
        </div>
      </div>

      {/* Title input */}
      <div className="space-y-2">
        <label className="block text-xs font-medium text-muted-foreground">
          {isTask ? "Task title" : "Event title"}
        </label>
        <Input
          autoFocus
          placeholder={isTask ? "Study JavaScript…" : "Team meeting…"}
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              submit();
            }
          }}
          className="text-sm"
        />
      </div>

      {/* Time controls */}
      {!isTask && (
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-2">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">Start</label>
              <Input
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                className="text-sm"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">End</label>
              <Input
                type="time"
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
                className="text-sm"
              />
            </div>
          </div>

          {/* Duration display */}
          <div className="flex items-center justify-between rounded-md bg-muted/50 px-3 py-2">
            <div className="flex items-center gap-2">
              <Clock className="h-4 w-4 text-muted-foreground" />
              <span className="text-sm font-medium">{durationText}</span>
            </div>
            {!isValidDuration && (
              <div className="flex items-center gap-1 text-xs text-destructive">
                <AlertCircle className="h-3.5 w-3.5" />
                Invalid
              </div>
            )}
          </div>

          {/* Presets */}
          {usePreset === false && <TimeBlockPresets onSelect={handlePresetSelect} />}
        </div>
      )}

      {/* Task due time */}
      {isTask && (
        <div className="space-y-2">
          <label className="text-xs font-medium text-muted-foreground">Due time</label>
          <Input
            type="time"
            value={startTime}
            onChange={(e) => setStartTime(e.target.value)}
            className="text-sm"
          />
        </div>
      )}

      {/* Notes (optional) */}
      <div className="space-y-2">
        <label className="text-xs font-medium text-muted-foreground">Notes (optional)</label>
        <Textarea
          placeholder="Add context, links, or details…"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          className="min-h-20 resize-none text-sm"
        />
      </div>

      {/* Actions */}
      <div className="flex justify-end gap-2 pt-2">
        <Button size="sm" type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button size="sm" type="button" onClick={submit} disabled={!title.trim() || !isValidDuration}>
          Create {isTask ? "Task" : "Event"}
        </Button>
      </div>
    </div>
  );
}
