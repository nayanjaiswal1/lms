"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { closeTicketAction } from "@/lib/mentoring/actions";

interface CloseTicketButtonProps {
  ticketId: string;
}

export function CloseTicketButton({ ticketId }: CloseTicketButtonProps) {
  const [pending, setPending] = useState(false);

  async function handleClose() {
    setPending(true);
    const result = await closeTicketAction(ticketId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Ticket closed.");
  }

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={handleClose}>
      {pending ? "Closing…" : "Close"}
    </Button>
  );
}
