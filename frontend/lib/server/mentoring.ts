import "server-only";

import { apiGet } from "@/lib/server/api";
import type { Enrollment } from "@/lib/server/courses";
import type { MentorTicketStatus, MentorChangeRequestStatus } from "@/lib/constants";

export interface MentorTicket {
  id: string;
  org_id: string;
  student_id: string;
  course_id: string;
  status: MentorTicketStatus;
  assigned_mentor_id: string | null;
  assigned_by: string | null;
  assigned_at: string | null;
  closed_at: string | null;
  escalation_level: number;
  created_at: string;
  updated_at: string;
}

export interface MentorDirectoryEntry {
  user_id: string;
  name: string;
  email: string;
  mentee_count: number;
  avg_rating: number | null;
  rating_count: number;
}

export interface CoursePurchase {
  id: string;
  org_id: string;
  user_id: string;
  course_id: string;
  amount_cents: number;
  currency: string;
  provider: string;
  provider_ref: string;
  status: string;
  purchased_at: string;
}

export interface CoursePurchaseResult {
  purchase: CoursePurchase;
  enrollment: Enrollment;
  ticket: MentorTicket | null;
}

export interface MentorTicketFilter {
  status?: MentorTicketStatus;
  mine?: boolean;
}

export interface MentorChangeRequest {
  id: string;
  org_id: string;
  ticket_id: string;
  student_id: string;
  reason: string;
  status: MentorChangeRequestStatus;
  reviewed_by: string | null;
  review_note: string | null;
  reviewed_at: string | null;
  created_at: string;
}

export async function getMentors(): Promise<MentorDirectoryEntry[]> {
  const body = await apiGet<{ mentors: MentorDirectoryEntry[] }>("/api/mentors");
  return body.mentors ?? [];
}

export async function getMentorTickets(filter: MentorTicketFilter = {}): Promise<MentorTicket[]> {
  const params = new URLSearchParams();
  if (filter.status) params.set("status", filter.status);
  if (filter.mine) params.set("mine", "true");
  const query = params.toString();
  const body = await apiGet<{ tickets: MentorTicket[] }>(`/api/mentor-tickets${query ? `?${query}` : ""}`);
  return body.tickets ?? [];
}

export async function getMyMentorTickets(): Promise<MentorTicket[]> {
  const body = await apiGet<{ tickets: MentorTicket[] }>("/api/mentor-tickets/me");
  return body.tickets ?? [];
}

// No single-ticket GET exists on the mentor-tickets API — the ticket queue is
// always listed in bulk, so this reuses that list rather than adding a new
// backend endpoint just for one lookup.
export async function getMentorTicketById(ticketId: string): Promise<MentorTicket | null> {
  const tickets = await getMentorTickets();
  return tickets.find((t) => t.id === ticketId) ?? null;
}

export async function getMentorChangeRequests(status?: MentorChangeRequestStatus): Promise<MentorChangeRequest[]> {
  const query = status ? `?status=${status}` : "";
  const body = await apiGet<{ requests: MentorChangeRequest[] }>(`/api/mentor-change-requests${query}`);
  return body.requests ?? [];
}

export interface MentorChatMessage {
  id: string;
  org_id: string;
  ticket_id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

export async function getMentorChatMessages(ticketId: string): Promise<MentorChatMessage[]> {
  const body = await apiGet<{ messages: MentorChatMessage[] }>(`/api/mentor-tickets/${ticketId}/messages`);
  return body.messages ?? [];
}
