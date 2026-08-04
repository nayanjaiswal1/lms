"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { SupportTicketCategory, SupportTicketPriority, SupportTicketStatus } from "@/lib/constants";
import type { SupportTicket, SupportMessage } from "@/lib/server/support";
import ROUTES from "@/lib/routes";

export async function createSupportTicketAction(
  subject: string,
  message: string,
): Promise<ActionResult<SupportTicket>> {
  const result = await apiAction<SupportTicket>("POST", "/api/support/tickets", { subject, message });
  if (result.ok) revalidatePath(ROUTES.SUPPORT);
  return result;
}

export async function updateSupportTicketPropertiesAction(
  ticketId: string,
  category: SupportTicketCategory,
  priority: SupportTicketPriority,
): Promise<ActionResult<SupportTicket>> {
  const result = await apiAction<SupportTicket>("PATCH", `/api/support/tickets/${ticketId}/properties`, { category, priority });
  if (result.ok) {
    revalidatePath(ROUTES.SUPPORT);
    revalidatePath(ROUTES.SUPPORT_QUEUE);
  }
  return result;
}

// Ticket detail is never its own route (see TicketChatPanel) — it renders as a
// ?ticket= param on either list page, so both must be revalidated.
export async function sendSupportMessageAction(ticketId: string, body: string): Promise<ActionResult<SupportMessage>> {
  const result = await apiAction<SupportMessage>("POST", `/api/support/tickets/${ticketId}/messages`, { body });
  if (result.ok) {
    revalidatePath(ROUTES.SUPPORT);
    revalidatePath(ROUTES.SUPPORT_QUEUE);
  }
  return result;
}

export async function updateSupportTicketStatusAction(
  ticketId: string,
  status: SupportTicketStatus,
): Promise<ActionResult<SupportTicket>> {
  const result = await apiAction<SupportTicket>("PATCH", `/api/support/tickets/${ticketId}/status`, { status });
  if (result.ok) {
    revalidatePath(ROUTES.SUPPORT);
    revalidatePath(ROUTES.SUPPORT_QUEUE);
  }
  return result;
}
