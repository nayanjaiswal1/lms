"use client"

import { parseAsBoolean, useQueryState } from "nuqs"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import type { TicketHistory } from "@/lib/server/mentoring"
import { formatDateTime } from "@/lib/mentoring/format"

interface Props {
  history: TicketHistory
}

export function TicketHistoryDialog({ history }: Props) {
  const [open, setOpen] = useQueryState("history", parseAsBoolean.withDefault(false))
  const { ticket, assignments } = history

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpen(next || null)}>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>Mentor request history</DialogTitle>
        </DialogHeader>

        <ol className="flex flex-col gap-3 text-sm">
          <li className="flex items-center justify-between gap-4">
            <span className="text-foreground">Requested</span>
            <span className="text-muted-foreground">{formatDateTime(ticket.created_at)}</span>
          </li>
          {assignments.map((a) => (
            <li key={a.id} className="flex items-center justify-between gap-4">
              <span className="text-foreground">Mentor assigned</span>
              <span className="text-muted-foreground">{formatDateTime(a.assigned_at)}</span>
            </li>
          ))}
          {ticket.closed_at && (
            <li className="flex items-center justify-between gap-4">
              <span className="text-foreground">Closed</span>
              <span className="text-muted-foreground">{formatDateTime(ticket.closed_at)}</span>
            </li>
          )}
        </ol>
      </DialogContent>
    </Dialog>
  )
}
