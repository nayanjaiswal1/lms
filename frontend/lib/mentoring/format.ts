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
