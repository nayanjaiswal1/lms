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
import { closeTicketAction, verifyMentorAction } from "@/lib/mentoring/actions"
import { useHasPermission } from "@/lib/auth/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"

interface Props {
  ticketId?: string
  canReport?: boolean
  mentorId: string
  verified: boolean
}

export function MentorProfileActions({ ticketId, canReport = false, mentorId, verified }: Props) {
  const [, setReportOpen] = useQueryState("report", parseAsBoolean.withDefault(false))
  const [, setRequestOpen] = useQueryState("request-change", parseAsBoolean.withDefault(false))
  const [, setHistoryOpen] = useQueryState("history", parseAsBoolean.withDefault(false))
  const [ending, setEnding] = useState(false)
  const [togglingVerified, setTogglingVerified] = useState(false)
  const router = useRouter()
  const canVerify = useHasPermission(PERMISSIONS.MENTORING.VERIFY_MENTORS)

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

  async function handleToggleVerified() {
    setTogglingVerified(true)
    const result = await verifyMentorAction(mentorId, !verified)
    setTogglingVerified(false)
    if (result.error) {
      toast.error(result.error)
      return
    }
    toast.success(verified ? "Verification removed." : "Mentor verified.")
    router.refresh()
  }

  // Nothing to act on: no active ticket, no past mentorship to report on,
  // and no permission to toggle verification.
  if (!ticketId && !canReport && !canVerify) return null

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
        {canReport && (
          <DropdownMenuItem onSelect={() => void setReportOpen(true)}>Report this mentor</DropdownMenuItem>
        )}
        {canVerify && (
          <DropdownMenuItem disabled={togglingVerified} onSelect={handleToggleVerified}>
            {togglingVerified ? "Saving…" : verified ? "Remove verification" : "Verify mentor"}
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
