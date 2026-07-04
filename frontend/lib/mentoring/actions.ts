"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { MentorReportReason } from "@/lib/constants";
import type { CoursePurchaseResult, MentorTicket, MentorChatMessage } from "@/lib/server/mentoring";
import ROUTES from "@/lib/routes";

export async function purchaseCourseAction(courseId: string): Promise<ActionResult<CoursePurchaseResult>> {
  const result = await apiAction<CoursePurchaseResult>("POST", `/api/courses/${courseId}/purchase`);
  if (result.ok) {
    revalidatePath(ROUTES.COURSES);
    revalidatePath(ROUTES.course(courseId));
    revalidatePath(ROUTES.MENTORING_TICKETS);
  }
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

export async function sendMentorChatMessageAction(
  ticketId: string,
  body: string,
): Promise<ActionResult<MentorChatMessage>> {
  const result = await apiAction<MentorChatMessage>("POST", `/api/mentor-tickets/${ticketId}/messages`, { body });
  if (result.ok) revalidatePath(ROUTES.mentoringTicketChat(ticketId));
  return result;
}
