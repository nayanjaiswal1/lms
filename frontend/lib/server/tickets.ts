import "server-only";

import { apiGet } from "@/lib/server/api";
import type { TicketKind, TicketCategory, TicketPriority, TicketStatus } from "@/lib/constants";

// Ticket mirrors tickets.Ticket (backend/internal/tickets/models.go). Fields
// meaningful to only one kind are nullable: subject/category/priority are
// support-only, course_id/purchase_id/escalation_level are mentorship-only.
export interface Ticket {
  id: string;
  org_id: string;
  kind: TicketKind;
  requester_id: string;
  course_id: string | null;
  purchase_id: string | null;
  subject: string | null;
  category: TicketCategory | null;
  priority: TicketPriority | null;
  status: TicketStatus;
  assigned_to: string | null;
  escalation_level: number;
  resolved_at: string | null;
  closed_at: string | null;
  created_at: string;
}

// TicketMessage mirrors tickets.Message.
export interface TicketMessage {
  id: string;
  org_id: string;
  ticket_id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

// TicketDetail mirrors tickets.TicketDetail — the ticket plus its full reply
// thread, returned by Get in one round trip.
export interface TicketDetail extends Ticket {
  messages: TicketMessage[];
}

// getMyTickets returns the caller's own tickets. kind omitted returns both
// support and mentorship tickets together — the merged "my tickets" view.
export async function getMyTickets(kind?: TicketKind): Promise<Ticket[]> {
  const query = kind ? `?kind=${kind}` : "";
  const body = await apiGet<{ tickets: Ticket[] }>(`/api/tickets/me${query}`);
  return body.tickets ?? [];
}

// getTicketQueue returns every ticket of kind in the org — the staff/mentor
// queue. Requires kind's QueuePermission (support.manage or
// mentoring.view_tickets); callers gate access before calling this.
export async function getTicketQueue(
  kind: TicketKind,
  opts?: { status?: TicketStatus; mine?: boolean },
): Promise<Ticket[]> {
  const params = new URLSearchParams({ kind });
  if (opts?.status) params.set("status", opts.status);
  if (opts?.mine) params.set("mine", "true");
  const body = await apiGet<{ tickets: Ticket[] }>(`/api/tickets?${params.toString()}`);
  return body.tickets ?? [];
}

// getTicket returns a single ticket's detail plus its full reply thread —
// allowed for its own requester, its current assignee, or a caller holding
// its kind's manage permission. The backend enforces this, so a caller
// lacking access simply gets a 403, which apiGet turns into a thrown error
// for the page's error.tsx boundary.
export async function getTicket(ticketId: string): Promise<TicketDetail> {
  return apiGet<TicketDetail>(`/api/tickets/${ticketId}`);
}
