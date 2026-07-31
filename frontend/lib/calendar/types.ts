// ─────────────────────────────────────────────
// Calendar domain types — the wire-contract shapes (Event, Attendee, enums)
// are the canonical source in lib/server/calendar.ts (a shared-lib module);
// they're re-exported here (type-only, so it's erased at compile time and
// never touches that file's "use server" runtime exports) for the calendar
// UI, which also needs the option lists derived from them. Boundaries lint
// forbids a shared-lib file depending on a feature-lib one, so the
// dependency only ever points this direction: feature-lib → shared-lib.
// ─────────────────────────────────────────────

export type {
  Attendee,
  AttendeeRole,
  CalendarEvent,
  CalendarEventDetail,
  CalendarEventPriority,
  CalendarEventScope,
  CalendarEventStatus,
  CalendarEventType,
  CalendarVisibility,
  CreateCalendarEventInput,
  EventInvite,
  RsvpStatus,
  UpdateCalendarEventInput,
} from "@/lib/server/calendar";

import type { AttendeeRole, CalendarEventPriority, CalendarEventType, CalendarVisibility } from "@/lib/server/calendar";

export const CALENDAR_EVENT_TYPE_OPTIONS: { label: string; value: CalendarEventType }[] = [
  { label: "Mentor session", value: "mentor_session" },
  { label: "Live class",     value: "live_class" },
  { label: "Deadline",       value: "deadline" },
  { label: "Custom",         value: "custom" },
  { label: "Task",           value: "task" },
];

// Only meaningful on event_type: "task" rows — badge/swatch classes reuse the
// same categorical token palette CALENDAR_LAYER_OPTIONS draws from.
export const CALENDAR_PRIORITY_OPTIONS: {
  label: string;
  value: CalendarEventPriority;
  badgeClassName: string;
  swatchClassName: string;
}[] = [
  { label: "Low",    value: "low",    badgeClassName: "badge-muted",       swatchClassName: "bg-muted-foreground" },
  { label: "Medium", value: "medium", badgeClassName: "badge-info",        swatchClassName: "bg-primary" },
  { label: "High",   value: "high",   badgeClassName: "badge-warning",     swatchClassName: "bg-warning" },
  { label: "Urgent", value: "urgent", badgeClassName: "badge-destructive", swatchClassName: "bg-destructive" },
];

// Lower rank sorts first (urgent → low); an unset priority always sorts last.
export const CALENDAR_PRIORITY_RANK: Record<CalendarEventPriority, number> = Object.fromEntries(
  [...CALENDAR_PRIORITY_OPTIONS].reverse().map((opt, i) => [opt.value, i]),
) as Record<CalendarEventPriority, number>;
export const CALENDAR_PRIORITY_UNSET_RANK = CALENDAR_PRIORITY_OPTIONS.length;

export const CALENDAR_VISIBILITY_OPTIONS: { label: string; value: CalendarVisibility }[] = [
  { label: "Private", value: "private" },
  { label: "Shared",  value: "shared" },
  { label: "Public",  value: "public" },
];

export const ATTENDEE_ROLE_OPTIONS: { label: string; value: AttendeeRole }[] = [
  { label: "Owner",  value: "owner" },
  { label: "Editor", value: "editor" },
  { label: "Viewer", value: "viewer" },
];

// ── UI-only option sets (view toggle, layer filters) — never referenced by
// the server action layer, so these live only here. ──────────────────────

export const CALENDAR_VIEW = {
  DAY:    "day",
  WEEK:   "week",
  MONTH:  "month",
  AGENDA: "agenda",
} as const;
export type CalendarView = (typeof CALENDAR_VIEW)[keyof typeof CALENDAR_VIEW];

export const CALENDAR_VIEW_OPTIONS = [
  { label: "Day",    value: CALENDAR_VIEW.DAY },
  { label: "Week",   value: CALENDAR_VIEW.WEEK },
  { label: "Month",  value: CALENDAR_VIEW.MONTH },
  { label: "Agenda", value: CALENDAR_VIEW.AGENDA },
] as const;

export const CALENDAR_LAYER = {
  MINE:       "mine",
  BATCH:      "batch",
  COURSE:     "course",
  MENTOR:     "mentor",
  ASSESSMENT: "assessment",
} as const;
export type CalendarLayer = (typeof CALENDAR_LAYER)[keyof typeof CALENDAR_LAYER];

// Swatch/text classes are drawn from the existing token palette only — the
// same reuse pattern as globals.css .difficulty-* (primary/success/warning/
// destructive as categorical hues, not literal severity). --ai is deliberately
// excluded: it is reserved app-wide for AI-generated content, and none of
// these layers are AI-generated.
export const CALENDAR_LAYER_OPTIONS: {
  label: string;
  value: CalendarLayer;
  swatchClassName: string;
  badgeClassName: string;
}[] = [
  { label: "My events",       value: CALENDAR_LAYER.MINE,       swatchClassName: "bg-primary",          badgeClassName: "badge-info" },
  { label: "Batch",           value: CALENDAR_LAYER.BATCH,       swatchClassName: "bg-success",         badgeClassName: "badge-success" },
  { label: "Course",          value: CALENDAR_LAYER.COURSE,      swatchClassName: "bg-muted-foreground", badgeClassName: "badge-muted" },
  { label: "Mentor sessions", value: CALENDAR_LAYER.MENTOR,      swatchClassName: "bg-destructive",     badgeClassName: "badge-destructive" },
  { label: "Assessments",     value: CALENDAR_LAYER.ASSESSMENT,  swatchClassName: "bg-warning",         badgeClassName: "badge-warning" },
];
