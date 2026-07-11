"use client";

import * as React from "react";
import { CheckCircle2, Circle, Clock, Zap, Filter } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import type { CalendarEvent } from "@/lib/calendar/types";

interface TimeBlocksDashboardProps {
  events: CalendarEvent[];
  currentUserId: string;
  onEventClick: (eventId: string) => void;
}

type FilterType = "all" | "tasks" | "events" | "today" | "overdue";

function getEventDuration(event: CalendarEvent): string {
  const start = new Date(event.starts_at);
  if (!event.ends_at) return "No duration";
  const end = new Date(event.ends_at);
  const minutes = Math.round((end.getTime() - start.getTime()) / (1000 * 60));
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
}

function isOverdue(event: CalendarEvent): boolean {
  if (event.event_type !== "task" || event.completed_at) return false;
  return new Date(event.starts_at) < new Date();
}

function isToday(date: Date): boolean {
  const today = new Date();
  return (
    date.getFullYear() === today.getFullYear() &&
    date.getMonth() === today.getMonth() &&
    date.getDate() === today.getDate()
  );
}

function formatDateTime(date: Date): string {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const month = months[date.getMonth()];
  const day = date.getDate();
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  return `${month} ${day}, ${hours}:${minutes}`;
}

export function TimeBlocksDashboard({ events, currentUserId, onEventClick }: TimeBlocksDashboardProps) {
  const [filter, setFilter] = React.useState<FilterType>("all");

  const filtered = events.filter((event) => {
    switch (filter) {
      case "tasks":
        return event.event_type === "task";
      case "events":
        return event.event_type !== "task";
      case "today":
        return isToday(new Date(event.starts_at));
      case "overdue":
        return isOverdue(event);
      default:
        return true;
    }
  });

  const sortedEvents = [...filtered].sort((a, b) => {
    const aDate = new Date(a.starts_at);
    const bDate = new Date(b.starts_at);
    return bDate.getTime() - aDate.getTime();
  });

  const stats = {
    total: filtered.length,
    tasks: filtered.filter((e) => e.event_type === "task").length,
    completed: filtered.filter((e) => e.completed_at).length,
    overdue: filtered.filter(isOverdue).length,
  };

  if (events.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border bg-card p-8 text-center">
        <div className="space-y-3">
          <Clock className="mx-auto h-8 w-8 text-muted-foreground" />
          <h3 className="font-medium">No time blocks yet</h3>
          <p className="text-sm text-muted-foreground">Click on a calendar slot to create your first time block</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-lg border border-border bg-card p-3">
          <div className="space-y-1">
            <p className="text-xs text-muted-foreground">Total blocks</p>
            <p className="text-lg font-semibold">{stats.total}</p>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-3">
          <div className="space-y-1">
            <p className="text-xs text-muted-foreground">Tasks</p>
            <p className="text-lg font-semibold">{stats.tasks}</p>
          </div>
        </div>
        <div className="rounded-lg border border-border bg-card p-3">
          <div className="space-y-1">
            <p className="text-xs text-muted-foreground">Completed</p>
            <p className="text-lg font-semibold text-primary">{stats.completed}</p>
          </div>
        </div>
        {stats.overdue > 0 && (
          <div className="rounded-lg border border-destructive/20 bg-destructive/5 p-3">
            <div className="space-y-1">
              <p className="text-xs text-destructive">Overdue</p>
              <p className="text-lg font-semibold text-destructive">{stats.overdue}</p>
            </div>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="space-y-2">
        <div className="flex items-center gap-2 text-xs font-medium text-muted-foreground">
          <Filter className="h-4 w-4" />
          Filter by
        </div>
        <div className="flex flex-wrap gap-2">
          {(["all", "tasks", "events", "today", "overdue"] as const).map((f) => (
            <Button
              key={f}
              size="sm"
              variant={filter === f ? "default" : "outline"}
              onClick={() => setFilter(f)}
              className="text-xs capitalize"
            >
              {f === "tasks" ? "Tasks only" : f === "events" ? "Events only" : f === "today" ? "Today" : f === "overdue" ? "Overdue" : "All"}
            </Button>
          ))}
        </div>
      </div>

      {/* Events list */}
      {sortedEvents.length === 0 ? (
        <div className="rounded-lg border border-dashed border-border bg-card p-8 text-center">
          <p className="text-sm text-muted-foreground">No blocks match this filter</p>
        </div>
      ) : (
        <div className="space-y-2">
          {sortedEvents.map((event) => {
            const start = new Date(event.starts_at);
            const isCompleted = Boolean(event.completed_at);
            const isTask = event.event_type === "task";
            const isOv = isOverdue(event);
            const duration = getEventDuration(event);

            return (
              <button
                key={event.id}
                onClick={() => onEventClick(event.id)}
                className="group flex w-full items-start gap-3 rounded-lg border border-border/50 bg-card p-3.5 text-left transition-colors hover:bg-muted/50 hover:border-border"
              >
                {/* Status indicator */}
                <div className="mt-0.5 flex-shrink-0">
                  {isTask ? (
                    isCompleted ? (
                      <CheckCircle2 className="h-5 w-5 text-primary" />
                    ) : (
                      <Circle className="h-5 w-5 text-muted-foreground" />
                    )
                  ) : (
                    <Zap className="h-5 w-5 text-primary" />
                  )}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2">
                    <h3
                      className={`font-medium leading-tight ${
                        isCompleted ? "line-through text-muted-foreground" : "text-foreground"
                      }`}
                    >
                      {event.title}
                    </h3>
                    <div className="flex flex-shrink-0 items-center gap-1.5">
                      {isOv && (
                        <Badge variant="destructive" className="text-xs">
                          Overdue
                        </Badge>
                      )}
                      {isCompleted && (
                        <Badge variant="outline" className="text-xs">
                          Done
                        </Badge>
                      )}
                      {!isTask && (
                        <Badge variant="secondary" className="text-xs whitespace-nowrap">
                          {duration}
                        </Badge>
                      )}
                    </div>
                  </div>

                  {/* Time and notes */}
                  <div className="mt-2 flex flex-col gap-1 text-xs text-muted-foreground sm:flex-row sm:items-center">
                    <span>{formatDateTime(start)}</span>
                    {event.notes && (
                      <>
                        <span className="hidden sm:inline">•</span>
                        <span className="truncate text-xs">{event.notes}</span>
                      </>
                    )}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
