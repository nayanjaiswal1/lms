import "server-only";

import { apiGet } from "@/lib/server/api";
import type { SupportTicketCategory, SupportTicketPriority, SupportTicketStatus } from "@/lib/constants";

// Ticket mirrors support.Ticket (backend/internal/support/models.go).
export interface SupportTicket {
  id: string;
  org_id: string;
  user_id: string;
  subject: string;
  category: SupportTicketCategory;
  priority: SupportTicketPriority;
  status: SupportTicketStatus;
  assigned_to: string | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
}

// SupportMessage mirrors support.Message (backend/internal/support/models.go).
export interface SupportMessage {
  id: string;
  org_id: string;
  ticket_id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

export async function getMySupportTickets(): Promise<SupportTicket[]> {
  const body = await apiGet<{ tickets: SupportTicket[] }>("/api/support/tickets/me");
  return body.tickets ?? [];
}

// Staff queue — requires support.manage; callers gate access before calling
// this (see app/(app)/support/queue/page.tsx).
export async function getAllSupportTickets(status?: SupportTicketStatus): Promise<SupportTicket[]> {
  const query = status ? `?status=${status}` : "";
  const body = await apiGet<{ tickets: SupportTicket[] }>(`/api/support/tickets${query}`);
  return body.tickets ?? [];
}

// Allowed for the ticket's own reporter or a caller holding support.manage —
// the backend enforces this, so a caller lacking access simply gets a 403,
// which apiGet turns into a thrown error for the page's error.tsx boundary.
export async function getSupportTicket(ticketId: string): Promise<SupportTicket> {
  return apiGet<SupportTicket>(`/api/support/tickets/${ticketId}`);
}

export async function getSupportTicketMessages(ticketId: string): Promise<SupportMessage[]> {
  const body = await apiGet<{ messages: SupportMessage[] }>(`/api/support/tickets/${ticketId}/messages`);
  return body.messages ?? [];
}
