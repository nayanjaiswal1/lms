"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Plus, Calendar, List, BarChart3 } from "lucide-react";
import { toast } from "sonner";
import { TimeBlocksDashboard } from "@/app/(app)/plan/time-blocks-dashboard";
import { WeekView } from "@/app/(app)/calendar/week-view";
import { EventPanel } from "@/app/(app)/calendar/event-panel";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import { EnhancedQuickCreate } from "@/app/(app)/calendar/enhanced-quick-create";
import type { CalendarEvent, CalendarEventDetail } from "@/lib/calendar/types";

interface SchedulePageProps {
  initialEvents: CalendarEvent[];
  currentUserId: string;
  onCreateEvent: (
    title: string,
    start: Date,
    end: Date,
    isTask: boolean,
    notes?: string
  ) => Promise<void>;
  onUpdateEvent: (
    eventId: string,
    updates: Partial<CalendarEvent>
  ) => Promise<void>;
  onDeleteEvent: (eventId: string) => Promise<void>;
  onGetEventDetail: (eventId: string) => Promise<CalendarEventDetail | null>;
}

type View = "week" | "list" | "stats";

export function SchedulePage({
  initialEvents,
  currentUserId,
  onCreateEvent,
  onUpdateEvent,
  onDeleteEvent,
  onGetEventDetail,
}: SchedulePageProps) {
  const [events, setEvents] = React.useState(initialEvents);
  const [view, setView] = React.useState<View>("week");
  const [selectedDate, setSelectedDate] = React.useState(new Date());
  const [selectedSlot, setSelectedSlot] = React.useState<Date | null>(null);
  const [selectedEventId, setSelectedEventId] = React.useState<string | null>(null);
  const [selectedEventDetail, setSelectedEventDetail] = React.useState<CalendarEventDetail | null>(null);
  const [isCreating, setIsCreating] = React.useState(false);
  const [loading, setLoading] = React.useState(false);

  const handleSlotClick = (day: Date, time: Date) => {
    setSelectedSlot(time);
    setIsCreating(true);
  };

  const handleEventClick = async (eventId: string) => {
    setSelectedEventId(eventId);
    setLoading(true);
    try {
      const detail = await onGetEventDetail(eventId);
      setSelectedEventDetail(detail);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateEvent = async (
    title: string,
    start: Date,
    end: Date,
    isTask: boolean,
    notes?: string
  ) => {
    try {
      setLoading(true);
      await onCreateEvent(title, start, end, isTask, notes);
      // Optimistically update the local state
      setEvents([
        ...events,
        {
          id: Math.random().toString(),
          title,
          starts_at: start.toISOString(),
          ends_at: end.toISOString(),
          event_type: isTask ? "task" : "custom",
          created_by: currentUserId,
          status: "scheduled",
          notes: notes || null,
          meeting_url: null,
          batch_id: null,
          course_id: null,
          recurrence_rule: null,
          visibility: "private",
          all_day: false,
          completed_at: null,
          is_virtual: false,
          org_id: "",
        } satisfies CalendarEvent,
      ]);
      setIsCreating(false);
      setSelectedSlot(null);
    } finally {
      setLoading(false);
    }
  };

  const defaultStart = selectedSlot || new Date();
  const defaultEnd = new Date(defaultStart.getTime() + 60 * 60 * 1000);

  const selectedEvent = selectedEventId
    ? (events.find((e) => e.id === selectedEventId) ?? null)
    : null;

  const closeEventPanel = () => {
    setSelectedEventId(null);
    setSelectedEventDetail(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Schedule</h1>
          <p className="mt-1 text-sm text-muted-foreground">Manage your time blocks, tasks, and events</p>
        </div>
        <Popover open={isCreating} onOpenChange={setIsCreating}>
          <PopoverAnchor asChild>
            <Button className="gap-2" onClick={() => setIsCreating(true)}>
              <Plus className="h-4 w-4" />
              <span className="hidden sm:inline">New time block</span>
              <span className="sm:hidden">Add</span>
            </Button>
          </PopoverAnchor>
          <PopoverContent className="w-96 max-w-[calc(100vw-2rem)] p-0">
            <EnhancedQuickCreate
              defaultStart={defaultStart}
              defaultEnd={defaultEnd}
              onCreate={handleCreateEvent}
              onCancel={() => setIsCreating(false)}
            />
          </PopoverContent>
        </Popover>
      </div>

      {/* Views */}
      <div className="space-y-4">
        {/* View toggle */}
        <div className="flex gap-2">
          {(["week", "list", "stats"] as const).map((v) => (
            <Button
              key={v}
              variant={view === v ? "default" : "outline"}
              size="sm"
              onClick={() => setView(v)}
              className="gap-2"
            >
              {v === "week" && <Calendar className="h-4 w-4" />}
              {v === "list" && <List className="h-4 w-4" />}
              {v === "stats" && <BarChart3 className="h-4 w-4" />}
              <span className="hidden sm:inline capitalize">{v}</span>
            </Button>
          ))}
        </div>

        {/* View content */}
        {view === "week" && (
          <WeekView
            anchor={selectedDate}
            events={events}
            currentUserId={currentUserId}
            onDateSelect={handleSlotClick}
            onEventClick={handleEventClick}
            onNavigate={(direction) => {
              const days = direction === "next" ? 7 : -7;
              setSelectedDate(new Date(selectedDate.getTime() + days * 24 * 60 * 60 * 1000));
            }}
          />
        )}

        {view === "list" && (
          <TimeBlocksDashboard
            events={events}
            currentUserId={currentUserId}
            onEventClick={handleEventClick}
          />
        )}

        {view === "stats" && <StatsView events={events} />}
      </div>

      {/* Event detail panel */}
      {selectedEvent && (
        <EventPanel
          key={selectedEvent.id}
          event={selectedEvent}
          attendees={selectedEventDetail?.attendees ?? null}
          pendingInvites={selectedEventDetail?.pending_invites ?? null}
          currentUserId={currentUserId}
          open
          onOpenChange={(open) => {
            if (!open) closeEventPanel();
          }}
          onAttendeeChanged={() => {}}
          onInvited={() => {}}
          onEventChanged={(updated) => {
            setEvents((prev) => prev.map((e) => (e.id === updated.id ? updated : e)));
            void onUpdateEvent;
            void onDeleteEvent;
          }}
          onRefetchNeeded={closeEventPanel}
        />
      )}
    </div>
  );
}

function StatsView({ events }: { events: CalendarEvent[] }) {
  const tasks = events.filter((e) => e.event_type === "task");
  const completed = tasks.filter((e) => e.completed_at).length;
  const totalEvents = events.filter((e) => e.event_type !== "task");
  const totalHours = events.reduce((acc, e) => {
    if (!e.ends_at) return acc;
    const start = new Date(e.starts_at);
    const end = new Date(e.ends_at);
    const minutes = (end.getTime() - start.getTime()) / (1000 * 60);
    return acc + minutes / 60;
  }, 0);

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Total tasks" value={tasks.length} />
      <StatCard label="Completed" value={completed} highlight="success" />
      <StatCard label="Total events" value={totalEvents.length} />
      <StatCard label="Hours scheduled" value={totalHours.toFixed(1)} />
    </div>
  );
}

function StatCard({
  label,
  value,
  highlight,
}: {
  label: string;
  value: string | number;
  highlight?: string;
}) {
  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p
        className={`mt-2 text-2xl font-bold ${
          highlight === "success" ? "text-primary" : ""
        }`}
      >
        {value}
      </p>
    </div>
  );
}
