import type { TicketStatus, TicketPriority } from "@/lib/constants";
import { TICKET_CATEGORY_OPTIONS } from "@/lib/constants";

type BadgeVariant = "default" | "secondary" | "outline" | "destructive";

// Single source of truth for how each ticket status/priority renders as a
// badge — shared by the "my tickets" list, both staff/mentor queue tables,
// and the ticket detail/chat pages, for both kinds of ticket.
export const TICKET_STATUS_VARIANT: Record<TicketStatus, BadgeVariant> = {
  open: "outline",
  in_progress: "default",
  assigned: "default",
  resolved: "secondary",
  closed: "secondary",
};

export const TICKET_PRIORITY_VARIANT: Record<TicketPriority, BadgeVariant> = {
  low: "outline",
  normal: "secondary",
  high: "destructive",
};

export const ESCALATION_LABEL: Record<number, string> = {
  1: "Escalated: 1 day",
  2: "Escalated: 3 days",
  3: "Escalated: 7 days",
};

const CATEGORY_LABEL = new Map<string, string>(TICKET_CATEGORY_OPTIONS.map((o) => [o.value, o.label]));

export function categoryLabel(category: string): string {
  return CATEGORY_LABEL.get(category) ?? category;
}

export function truncateId(id: string): string {
  return `${id.slice(0, 8)}…`;
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString();
}

export function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}
