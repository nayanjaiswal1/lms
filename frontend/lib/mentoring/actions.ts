"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { MentorReportReason } from "@/lib/constants";
import type {
  CheckoutSession,
  PurchaseStatusResult,
  CouponPreview,
  MentorTicket,
  MentorChatMessage,
  MentorConversation,
  DirectMessage,
} from "@/lib/server/mentoring";
import type { Certificate } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

// Starts a paid-course checkout. Does NOT grant access by itself — the
// caller follows redirect_url or opens client_params, then the checkout
// return page polls purchaseStatusAction until a webhook confirms it.
export async function startCheckoutAction(
  courseId: string,
  opts?: { provider?: string; couponCode?: string },
): Promise<ActionResult<CheckoutSession>> {
  return apiAction<CheckoutSession>("POST", `/api/courses/${courseId}/checkout`, {
    provider: opts?.provider,
    coupon_code: opts?.couponCode,
  });
}

export async function previewCouponAction(courseId: string, code: string): Promise<ActionResult<CouponPreview>> {
  return apiAction<CouponPreview>("POST", `/api/courses/${courseId}/coupon/preview`, { code });
}

// Polled by the checkout return page. Revalidates course/enrollment pages
// only once the purchase is actually confirmed — a still-pending poll must
// not make the UI look like anything succeeded yet.
export async function purchaseStatusAction(courseId: string): Promise<ActionResult<PurchaseStatusResult>> {
  const result = await apiAction<PurchaseStatusResult>("GET", `/api/courses/${courseId}/purchase-status`);
  if (result.ok && result.data?.status === "completed") {
    revalidatePath(ROUTES.COURSES);
    revalidatePath(ROUTES.course(courseId));
    revalidatePath(ROUTES.MENTORING_TICKETS);
  }
  return result;
}

// Admin-triggered only (payments.manage_refunds) — never self-serve, so a
// human always reviews the request before money moves back out.
export async function refundPurchaseAction(courseId: string, purchaseId: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/courses/${courseId}/purchases/${purchaseId}/refund`);
  if (result.ok) revalidatePath(ROUTES.course(courseId));
  return result;
}

export async function requestMentorAction(courseId: string): Promise<ActionResult<MentorTicket>> {
  const result = await apiAction<MentorTicket>("POST", "/api/mentor-tickets/request", { course_id: courseId });
  if (result.ok) revalidatePath(ROUTES.MENTORS);
  return result;
}

export async function claimTicketAction(ticketId: string): Promise<ActionResult<MentorTicket>> {
  const result = await apiAction<MentorTicket>("POST", `/api/mentor-tickets/${ticketId}/claim`);
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}

export async function assignTicketAction(ticketId: string, mentorId: string): Promise<ActionResult<MentorTicket>> {
  const result = await apiAction<MentorTicket>("POST", `/api/mentor-tickets/${ticketId}/assign`, {
    mentor_id: mentorId,
  });
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}

export async function closeTicketAction(ticketId: string): Promise<ActionResult<MentorTicket>> {
  const result = await apiAction<MentorTicket>("POST", `/api/mentor-tickets/${ticketId}/close`);
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}

export async function reportMentorAction(
  mentorId: string,
  reason: MentorReportReason,
  description: string,
  ticketId?: string,
): Promise<ActionResult> {
  return apiAction("POST", `/api/mentors/${mentorId}/report`, {
    reason,
    description,
    ticket_id: ticketId,
  });
}

export async function rateMentorAction(
  mentorId: string,
  rating: number,
  comment?: string,
): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/feedback", {
    subject_type: "mentor",
    subject_id: mentorId,
    rating,
    comment,
  });
  if (result.ok) revalidatePath(ROUTES.mentor(mentorId));
  return result;
}

export async function requestMentorChangeAction(ticketId: string, reason: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/mentor-tickets/${ticketId}/change-request`, { reason });
  if (result.ok) revalidatePath(ROUTES.MENTORS);
  return result;
}

export async function approveChangeRequestAction(requestId: string, note?: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/mentor-change-requests/${requestId}/approve`, { note });
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}

export async function denyChangeRequestAction(requestId: string, note?: string): Promise<ActionResult> {
  const result = await apiAction("POST", `/api/mentor-change-requests/${requestId}/deny`, { note });
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}

export async function resolveReportAction(
  reportId: string,
  status: "resolved" | "dismissed",
  note?: string,
): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/mentor-reports/${reportId}`, {
    status,
    resolution_note: note,
  });
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}

export async function sendMentorChatMessageAction(
  ticketId: string,
  body: string,
): Promise<ActionResult<MentorChatMessage>> {
  const result = await apiAction<MentorChatMessage>("POST", `/api/mentor-tickets/${ticketId}/messages`, { body });
  if (result.ok) revalidatePath(ROUTES.mentoringTicketChat(ticketId));
  return result;
}

export async function verifyMentorAction(mentorId: string, verified: boolean): Promise<ActionResult> {
  const result = await apiAction("PATCH", `/api/mentors/${mentorId}/verify`, { verified });
  if (result.ok) revalidatePath(ROUTES.mentor(mentorId));
  return result;
}

// Starts (or resumes) a ticket-independent DM thread with a mentor. Returns
// the conversation so the caller can route to its chat page.
export async function createOrGetConversationAction(
  mentorId: string,
): Promise<ActionResult<MentorConversation>> {
  return apiAction<MentorConversation>("POST", "/api/mentor-conversations", { mentor_id: mentorId });
}

export async function sendConversationMessageAction(
  conversationId: string,
  body: string,
): Promise<ActionResult<DirectMessage>> {
  const result = await apiAction<DirectMessage>("POST", `/api/mentor-conversations/${conversationId}/messages`, {
    body,
  });
  if (result.ok) revalidatePath(ROUTES.mentorConversation(conversationId));
  return result;
}

// A mentor may only issue for their own assigned student (enforced
// server-side); instructor/admin may issue for any enrolled student.
export async function issueCertificateAction(
  courseId: string,
  studentId: string,
): Promise<ActionResult<Certificate>> {
  const result = await apiAction<Certificate>("POST", `/api/courses/${courseId}/certificates/issue`, {
    student_id: studentId,
  });
  if (result.ok) revalidatePath(ROUTES.MENTORING_TICKETS);
  return result;
}
