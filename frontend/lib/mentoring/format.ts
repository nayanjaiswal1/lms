import type { MentorTicketStatus, MentorChangeRequestStatus, MentorReportStatus } from "@/lib/constants";

type BadgeVariant = "default" | "secondary" | "outline" | "destructive";

// Single source of truth for how each mentoring status renders as a badge —
// shared by the ticket queue table, the ticket detail page, and any future
// surface that lists tickets/change-requests/reports, so a new status value
// only ever needs a color decision made once.
export const TICKET_STATUS_VARIANT: Record<MentorTicketStatus, BadgeVariant> = {
  open: "outline",
  assigned: "default",
  closed: "secondary",
};

export const CHANGE_REQUEST_STATUS_VARIANT: Record<MentorChangeRequestStatus, BadgeVariant> = {
  pending: "outline",
  approved: "default",
  denied: "destructive",
};

export const REPORT_STATUS_VARIANT: Record<MentorReportStatus, BadgeVariant> = {
  open: "outline",
  reviewing: "default",
  resolved: "secondary",
  dismissed: "destructive",
};

export const ESCALATION_LABEL: Record<number, string> = {
  1: "Escalated: 1 day",
  2: "Escalated: 3 days",
  3: "Escalated: 7 days",
};

export function truncateId(id: string): string {
  return `${id.slice(0, 8)}…`;
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString();
}

export function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

// "38m" under an hour, "2.5h" otherwise — matches the profile insights panel.
export function formatResponseTime(minutes: number | null): string | null {
  if (minutes === null) return null;
  if (minutes < 60) return `${Math.round(minutes)}m`;
  return `${(minutes / 60).toFixed(1)}h`;
}

export function formatDuration(hours: number | null): string | null {
  if (hours === null) return null;
  return `${hours.toFixed(hours < 10 ? 1 : 0)}h`;
}

const RELATIVE_TIME = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" });
const RELATIVE_UNITS: [Intl.RelativeTimeFormatUnit, number][] = [
  ["year", 60 * 60 * 24 * 365],
  ["month", 60 * 60 * 24 * 30],
  ["week", 60 * 60 * 24 * 7],
  ["day", 60 * 60 * 24],
  ["hour", 60 * 60],
  ["minute", 60],
];

// "Last active 15 mins ago" — null when the platform has never recorded
// activity for this user (e.g. an account created before last_active_at
// tracking shipped, and never logged in since).
export function formatLastActive(iso: string | null): string | null {
  if (iso === null) return null;
  const seconds = (new Date(iso).getTime() - Date.now()) / 1000;
  for (const [unit, secondsInUnit] of RELATIVE_UNITS) {
    if (Math.abs(seconds) >= secondsInUnit) {
      return RELATIVE_TIME.format(Math.round(seconds / secondsInUnit), unit);
    }
  }
  return RELATIVE_TIME.format(0, "minute");
}
