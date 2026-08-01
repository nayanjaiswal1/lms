import "server-only";

import { apiGet } from "@/lib/server/api";
import type {
  MentorTicketStatus,
  MentorChangeRequestStatus,
  MentorReportReason,
  MentorReportStatus,
} from "@/lib/constants";

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
  avatar_url: string | null;
  mentee_count: number;
  avg_rating: number | null;
  rating_count: number;
  bio: string | null;
  current_role: string | null;
  years_of_experience: number | null;
  skills: string[];
  joined_at: string;
}

// CheckoutSession mirrors courses.CheckoutSession (backend/internal/courses/handler.go)
// — what POST /api/courses/{id}/checkout returns. Exactly one of
// redirect_url (Stripe hosted Checkout) or client_params (Razorpay
// Checkout.js) is set, unless status is already "completed" (a 100%-off
// coupon), in which case neither is.
export interface CheckoutSession {
  purchase_id: string;
  provider: string;
  status: "pending" | "completed";
  redirect_url?: string;
  client_params?: Record<string, string>;
  amount_cents: number;
  discount_cents: number;
  currency: string;
}

// PurchaseStatusResult mirrors courses.PurchaseStatus — polled by the
// checkout return page. The gateway redirect itself never grants access;
// only enrolled: true (set once a webhook confirms the purchase) does.
export interface PurchaseStatusResult {
  purchase_id: string;
  status: string;
  enrolled: boolean;
  ticket_id?: string;
}

// CouponPreview mirrors coupons.Preview — advisory only, the backend always
// recomputes the discount again server-side at checkout confirmation.
export interface CouponPreview {
  code: string;
  discount_cents: number;
  final_amount_cents: number;
  original_amount_cents: number;
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

// MentorProfile is the single-mentor superset of MentorDirectoryEntry shown
// on the profile page — adds the verified badge and three live-computed
// stats (see backend/internal/mentoring/models.go for exact definitions).
// The three stat fields are null when there isn't enough data yet (a new
// mentor with no tickets/sessions), never a fabricated placeholder.
export interface MentorProfile {
  user_id: string;
  name: string;
  email: string;
  avatar_url: string | null;
  mentee_count: number;
  avg_rating: number | null;
  rating_count: number;
  bio: string | null;
  current_role: string | null;
  years_of_experience: number | null;
  skills: string[];
  joined_at: string;
  verified: boolean;
  verified_at: string | null;
  avg_response_minutes: number | null;
  total_mentorship_hours: number | null;
  percentile_rank: number | null;
  last_active_at: string | null;
  linkedin: string | null;
  github: string | null;
  portfolio: string | null;
}

export async function getMentorProfile(mentorId: string): Promise<MentorProfile | null> {
  try {
    return await apiGet<MentorProfile>(`/api/mentors/${mentorId}/profile`);
  } catch {
    return null;
  }
}

// MentorConversation is a ticket-independent DM thread between a student
// and a mentor — separate from MentorTicket/MentorChatMessage, which are
// scoped to a course-enrollment mentorship assignment.
export interface MentorConversation {
  id: string;
  org_id: string;
  student_id: string;
  mentor_id: string;
  created_at: string;
  updated_at: string;
}

export interface DirectMessage {
  id: string;
  org_id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

export async function getMyConversations(): Promise<MentorConversation[]> {
  const body = await apiGet<{ conversations: MentorConversation[] }>("/api/mentor-conversations");
  return body.conversations ?? [];
}

export async function getConversationMessages(conversationId: string): Promise<DirectMessage[]> {
  const body = await apiGet<{ messages: DirectMessage[] }>(`/api/mentor-conversations/${conversationId}/messages`);
  return body.messages ?? [];
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

// Reuses /history rather than getMentorTickets(): that list endpoint is
// staff-only (mentorOrStaff), but this lookup also has to work for the
// ticket's own student (e.g. the chat page) — /history is already scoped to
// exactly that audience (student or the currently assigned mentor).
export async function getMentorTicketById(ticketId: string): Promise<MentorTicket | null> {
  try {
    const { ticket } = await getTicketHistory(ticketId);
    return ticket;
  } catch {
    return null;
  }
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

export interface TicketAssignment {
  id: string;
  ticket_id: string;
  mentor_id: string;
  assigned_at: string;
}

export interface TicketHistory {
  ticket: MentorTicket;
  assignments: TicketAssignment[];
}

export async function getTicketHistory(ticketId: string): Promise<TicketHistory> {
  return apiGet<TicketHistory>(`/api/mentor-tickets/${ticketId}/history`);
}

export interface MentorReport {
  id: string;
  org_id: string;
  mentor_id: string;
  reporter_id: string;
  ticket_id: string | null;
  reason: MentorReportReason;
  description: string;
  status: MentorReportStatus;
  resolved_by: string | null;
  resolution_note: string | null;
  resolved_at: string | null;
  created_at: string;
}

// The single source of truth for a ticket's full lifecycle — assignments,
// change requests, and (only when the caller holds
// mentoring.manage_reports) reports. `reports` is undefined, not an empty
// array, when the backend omitted it for lack of permission.
export interface TicketDetail {
  ticket: MentorTicket;
  assignments: TicketAssignment[];
  change_requests: MentorChangeRequest[];
  reports?: MentorReport[];
}

export async function getMentorTicketDetail(ticketId: string): Promise<TicketDetail> {
  return apiGet<TicketDetail>(`/api/mentor-tickets/${ticketId}/detail`);
}
