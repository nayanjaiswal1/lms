"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Loader2, Terminal } from "lucide-react"
import { Button } from "@/components/ui/button"
import { toast } from "sonner"
import { startLabSessionAction, endLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { useLabProvisioning } from "@/lib/labs/provisioning-context"
import { cn } from "@/lib/utils"
import ROUTES from "@/lib/routes"
import { isLabSessionAlreadyEnded, type Lab } from "@/lib/labs"

interface LabStartButtonProps {
  lab: Lab
  className?: string
  label?: string
}

// Starts a lab session. Code-type labs are ready immediately, so we route
// straight there. Every other lab type provisions a container in the
// background — LabProvisioningWatcher (mounted in the root layout) tracks
// readiness via toast so the user isn't stuck on a blocking full-page spinner
// and can keep browsing until the environment is ready.
//
// The backend only allows one active lab per user (labs.Service.StartSession),
// so this button has three states beyond idle: provisioning this lab, this
// lab already running/paused (resumable), or a *different* lab active
// elsewhere. That last case stays clickable — it offers a way out (end the
// other lab and switch, or jump to resume it) instead of just sitting
// disabled with no path forward.
export function LabStartButton({ lab, className, label = "Launch Lab" }: LabStartButtonProps) {
  const [isStarting, setIsStarting] = useState(false)
  const router = useRouter()
  const { session, track, clear } = useLabProvisioning()

  const isThisLab = session?.lab_id === lab.id
  const isOtherLabActive = session !== null && !isThisLab
  const isProvisioningThisLab = isThisLab && session?.status === "provisioning"
  const isResumable = isThisLab && (session?.status === "running" || session?.status === "paused")
  const isBusy = isStarting || isProvisioningThisLab

  const startThisLab = async () => {
    setIsStarting(true)
    const idempotencyKey = crypto.randomUUID()

    try {
      const result = await startLabSessionAction(lab.id, idempotencyKey)
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to start lab session.")
        setIsStarting(false)
        return
      }

      if (result.data.status === "running") {
        router.push(ROUTES.labSession(result.data.id))
        return
      }

      track({
        session_id: result.data.id,
        lab_id: lab.id,
        lab_title: lab.title,
        lab_type: lab.lab_type,
        status: result.data.status,
        started_at: result.data.started_at,
        expires_at: result.data.expires_at,
        last_active_at: result.data.last_active_at,
      })
      setIsStarting(false)
    } catch {
      toast.error("Something went wrong. Please try again.")
      setIsStarting(false)
    }
  }

  const endOtherAndSwitch = async () => {
    if (!session) return
    setIsStarting(true)
    const result = await endLabSessionAction(session.session_id)
    if (result.error && !isLabSessionAlreadyEnded(result.error)) {
      toast.error(result.error)
      setIsStarting(false)
      return
    }
    clear(session.session_id)
    await startThisLab()
  }

  const handleClick = () => {
    if (isBusy) return

    if (isOtherLabActive && session) {
      toast(`${session.lab_title} is still running`, {
        description: "End it to start this lab instead — you can only run one lab at a time.",
        duration: 8000,
        action: { label: "End & switch", onClick: () => void endOtherAndSwitch() },
        cancel: {
          label: "Resume other lab",
          onClick: () => router.push(ROUTES.labSession(session.session_id)),
        },
      })
      return
    }

    if (typeof window !== "undefined" && window.innerWidth < 768) {
      toast.warning(
        "Labs work best on a larger screen. The terminal may be difficult to use on mobile.",
        { duration: 4000 },
      )
    }

    void startThisLab()
  }

  const buttonLabel = isStarting
    ? "Starting…"
    : isProvisioningThisLab
      ? "Provisioning…"
      : isOtherLabActive
        ? "Another lab is active"
        : isResumable
          ? "Resume Lab"
          : label

  return (
    <Button
      size="lg"
      onClick={handleClick}
      disabled={isBusy}
      className={cn("w-full sm:w-auto", className)}
      aria-label={isBusy ? buttonLabel : `Start ${lab.title}`}
    >
      {isStarting || isProvisioningThisLab ? (
        <>
          <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden />
          {buttonLabel}
        </>
      ) : (
        <>
          <Terminal aria-hidden className="mr-2 h-4 w-4" />
          {buttonLabel}
        </>
      )}
    </Button>
  )
}
