import "server-only";

import { apiGet } from "@/lib/server/api";
import type { MentorChangeRequestStatus, MentorReportReason, MentorReportStatus } from "@/lib/constants";
import type { Ticket } from "@/lib/server/tickets";

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

// Receipt mirrors courses.Receipt — GET /api/courses/{id}/purchases/{purchaseId}/receipt.
// No tax breakdown/GSTIN fields: a plain payment receipt, not a GST invoice
// (see docs/infrastructure.md Payments section — the platform isn't GST-registered).
export interface Receipt {
  purchase_id: string;
  receipt_number: string | null;
  course_id: string;
  amount_cents: number;
  discount_cents: number;
  currency: string;
  provider: string;
  status: string;
  purchased_at: string;
}

export async function getReceipt(courseId: string, purchaseId: string): Promise<Receipt> {
  return apiGet<Receipt>(`/api/courses/${courseId}/purchases/${purchaseId}/receipt`);
}

// CouponPreview mirrors coupons.Preview — advisory only, the backend always
// recomputes the discount again server-side at checkout confirmation.
export interface CouponPreview {
  code: string;
  discount_cents: number;
  final_amount_cents: number;
  original_amount_cents: number;
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
// and a mentor — separate from a mentorship Ticket (@/lib/server/tickets),
// which is scoped to a course-enrollment mentorship assignment.
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

export async function getMentorChangeRequests(status?: MentorChangeRequestStatus): Promise<MentorChangeRequest[]> {
  const query = status ? `?status=${status}` : "";
  const body = await apiGet<{ requests: MentorChangeRequest[] }>(`/api/mentor-change-requests${query}`);
  return body.requests ?? [];
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

// The single source of truth for a ticket's full lifecycle — the ticket,
// its change requests, and (only when the caller holds
// mentoring.manage_reports) reports. `reports` is undefined, not an empty
// array, when the backend omitted it for lack of permission. Mentor-ticket
// assignment history was dropped from the backend (it was synthetic — see
// backend/internal/mentoring/models.go's TicketLifecycle doc comment) — the
// detail page derives its "assigned" timeline event from ticket.assigned_to
// directly instead of a separate assignments list.
export interface TicketLifecycle {
  ticket: Ticket;
  change_requests: MentorChangeRequest[];
  reports?: MentorReport[];
}

export async function getMentorTicketDetail(ticketId: string): Promise<TicketLifecycle> {
  return apiGet<TicketLifecycle>(`/api/mentor-tickets/${ticketId}/detail`);
}
