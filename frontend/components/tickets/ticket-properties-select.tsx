"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { TICKET_CATEGORY_OPTIONS, TICKET_PRIORITY_OPTIONS } from "@/lib/constants";
import type { TicketCategory, TicketPriority } from "@/lib/constants";
import { updateSupportTicketPropertiesAction } from "@/lib/tickets/actions";

interface TicketPropertiesSelectProps {
  ticketId: string;
  category: TicketCategory;
  priority: TicketPriority;
}

// Staff-only triage control, support tickets only — autosaves on change,
// same pattern as TicketStatusSelect. Category and priority always update
// together since the backend endpoint takes both at once.
export function TicketPropertiesSelect({ ticketId, category, priority }: TicketPropertiesSelectProps) {
  const router = useRouter();
  const [pending, setPending] = useState(false);

  async function update(nextCategory: string, nextPriority: string) {
    setPending(true);
    const result = await updateSupportTicketPropertiesAction(
      ticketId,
      nextCategory as TicketCategory,
      nextPriority as TicketPriority,
    );
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    router.refresh();
  }

  return (
    <div className="flex flex-wrap gap-2">
      <Select disabled={pending} value={category} onValueChange={(next) => void update(next, priority)}>
        <SelectTrigger aria-label="Category" className="w-full sm:w-[9.5rem]">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {TICKET_CATEGORY_OPTIONS.map((opt) => (
            <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Select disabled={pending} value={priority} onValueChange={(next) => void update(category, next)}>
        <SelectTrigger aria-label="Priority" className="w-full sm:w-28">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {TICKET_PRIORITY_OPTIONS.map((opt) => (
            <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
