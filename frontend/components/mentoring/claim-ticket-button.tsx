"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { claimTicketAction } from "@/lib/mentoring/actions";

interface ClaimTicketButtonProps {
  ticketId: string;
}

export function ClaimTicketButton({ ticketId }: ClaimTicketButtonProps) {
  const [pending, setPending] = useState(false);

  async function handleClaim() {
    setPending(true);
    const result = await claimTicketAction(ticketId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Ticket claimed.");
  }

  return (
    <Button disabled={pending} size="sm" onClick={handleClaim}>
      {pending ? "Claiming…" : "Claim"}
    </Button>
  );
}
