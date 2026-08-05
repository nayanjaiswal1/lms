"use server";

import { revalidatePath } from "next/cache";
import { apiAction, type ActionResult } from "@/lib/server/api";
import type { TicketCategory, TicketPriority, TicketStatus } from "@/lib/constants";
import type { Ticket, TicketMessage } from "@/lib/server/tickets";
import ROUTES from "@/lib/routes";

export async function createSupportTicketAction(subject: string, message: string): Promise<ActionResult<Ticket>> {
  const result = await apiAction<Ticket>("POST", "/api/tickets", { subject, message });
  if (result.ok) revalidatePath(ROUTES.SUPPORT);
  return result;
}

export async function updateSupportTicketPropertiesAction(
  ticketId: string,
  category: TicketCategory,
  priority: TicketPriority,
): Promise<ActionResult<Ticket>> {
  const result = await apiAction<Ticket>("PATCH", `/api/tickets/${ticketId}/properties`, { category, priority });
  if (result.ok) revalidatePath(ROUTES.SUPPORT);
  return result;
}

export async function updateSupportTicketStatusAction(ticketId: string, status: TicketStatus): Promise<ActionResult<Ticket>> {
  const result = await apiAction<Ticket>("PATCH", `/api/tickets/${ticketId}/status`, { status });
  if (result.ok) revalidatePath(ROUTES.SUPPORT);
  return result;
}

// Shared composer action for both surfaces: the support ticket floating
// panel (renders as a ?ticket= param on either list page) and the mentor
// ticket chat page. Revalidates every path a message could be read back
// from rather than branching on kind, since the caller already knows which
// page it's on and only that page's cache actually needs the refresh.
export async function sendTicketMessageAction(ticketId: string, body: string): Promise<ActionResult<TicketMessage>> {
  const result = await apiAction<TicketMessage>("POST", `/api/tickets/${ticketId}/messages`, { body });
  if (result.ok) {
    revalidatePath(ROUTES.SUPPORT);
    revalidatePath(ROUTES.mentoringTicketChat(ticketId));
  }
  return result;
}
