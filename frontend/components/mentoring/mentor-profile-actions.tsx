"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { MoreVertical } from "lucide-react"
import { parseAsBoolean, useQueryState } from "nuqs"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { closeTicketAction } from "@/lib/mentoring/actions"

interface Props {
  ticketId?: string
}

export function MentorProfileActions({ ticketId }: Props) {
  const [, setReportOpen] = useQueryState("report", parseAsBoolean.withDefault(false))
  const [, setRequestOpen] = useQueryState("request-change", parseAsBoolean.withDefault(false))
  const [, setHistoryOpen] = useQueryState("history", parseAsBoolean.withDefault(false))
  const [ending, setEnding] = useState(false)
  const router = useRouter()

  async function handleEndMentorship() {
    if (!ticketId) return
    setEnding(true)
    const result = await closeTicketAction(ticketId)
    setEnding(false)
    if (result.error) {
      toast.error(result.error)
      return
    }
    toast.success("Mentorship ended.")
    router.refresh()
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" aria-label="Mentor actions" className="touch-target">
          <MoreVertical aria-hidden className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {ticketId && (
          <>
            <DropdownMenuItem onSelect={() => void setRequestOpen(true)}>
              Request a different mentor
            </DropdownMenuItem>
            <DropdownMenuItem onSelect={() => void setHistoryOpen(true)}>See history</DropdownMenuItem>
            <DropdownMenuItem disabled={ending} onSelect={handleEndMentorship}>
              {ending ? "Ending…" : "End mentorship"}
            </DropdownMenuItem>
          </>
        )}
        <DropdownMenuItem onSelect={() => void setReportOpen(true)}>Report this mentor</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
