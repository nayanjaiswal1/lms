import type { SupportTicketStatus, SupportTicketPriority } from "@/lib/constants";
import { SUPPORT_TICKET_CATEGORY_OPTIONS } from "@/lib/constants";

type BadgeVariant = "default" | "secondary" | "outline" | "destructive";

// Single source of truth for how each ticket status/priority renders as a
// badge — shared by the "my tickets" list, the staff queue table, and the
// ticket detail page, mirroring lib/mentoring/format.ts's TICKET_STATUS_VARIANT.
export const SUPPORT_STATUS_VARIANT: Record<SupportTicketStatus, BadgeVariant> = {
  open: "outline",
  in_progress: "default",
  resolved: "secondary",
  closed: "secondary",
};

export const SUPPORT_PRIORITY_VARIANT: Record<SupportTicketPriority, BadgeVariant> = {
  low: "outline",
  normal: "secondary",
  high: "destructive",
};

const CATEGORY_LABEL = new Map<string, string>(SUPPORT_TICKET_CATEGORY_OPTIONS.map((o) => [o.value, o.label]));

export function categoryLabel(category: string): string {
  return CATEGORY_LABEL.get(category) ?? category;
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString();
}
