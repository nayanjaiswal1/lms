"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { SUPPORT_TICKET_STATUS_OPTIONS } from "@/lib/constants";
import type { SupportTicketStatus } from "@/lib/constants";
import { updateSupportTicketStatusAction } from "@/lib/support/actions";

interface TicketStatusSelectProps {
  ticketId: string;
  status: SupportTicketStatus;
}

// Staff-only status control — autosaves on change (no separate submit
// button) since a queue is worked one status flip at a time, not as a form.
export function TicketStatusSelect({ ticketId, status }: TicketStatusSelectProps) {
  const router = useRouter();
  const [pending, setPending] = useState(false);

  async function handleChange(next: string) {
    setPending(true);
    const result = await updateSupportTicketStatusAction(ticketId, next as SupportTicketStatus);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  return (
    <Select disabled={pending} value={status} onValueChange={handleChange}>
      <SelectTrigger aria-label="Ticket status" className="w-full sm:w-40">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {SUPPORT_TICKET_STATUS_OPTIONS.map((opt) => (
          <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
