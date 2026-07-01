"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Loader2, Terminal, Code2, Beaker, BookOpen } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { toast } from "sonner"
import { startLabSessionAction } from "@/app/(app)/labs/[labId]/actions"
import { cn } from "@/lib/utils"
import ROUTES from "@/lib/routes"
import type { Lab, LabType } from "@/lib/labs"

interface LabLauncherProps {
  lab: Lab
}

const LAB_TYPE_ICONS: Record<LabType, React.ComponentType<{ className?: string }>> = {
  terminal: Terminal,
  code: Code2,
  playground: Beaker,
  guided: BookOpen,
}

const LAB_TYPE_LABELS: Record<LabType, string> = {
  terminal: "Terminal",
  code: "Code",
  playground: "Playground",
  guided: "Guided",
}

export function LabLauncher({ lab }: LabLauncherProps) {
  const [isStarting, setIsStarting] = useState(false)
  const router = useRouter()
  const Icon = LAB_TYPE_ICONS[lab.lab_type]

  const handleStart = async () => {
    if (typeof window !== "undefined" && window.innerWidth < 768) {
      toast.warning(
        "Labs work best on a larger screen. The terminal may be difficult to use on mobile.",
        { duration: 4000 },
      )
    }

    setIsStarting(true)
    const idempotencyKey = crypto.randomUUID()

    try {
      const result = await startLabSessionAction(lab.id, idempotencyKey)
      if (result.error || !result.data) {
        toast.error(result.error ?? "Failed to start lab session.")
        setIsStarting(false)
        return
      }
      router.push(ROUTES.labSession(result.data.id))
    } catch {
      toast.error("Something went wrong. Please try again.")
      setIsStarting(false)
    }
  }

  return (
    <div className="card-base p-6 flex flex-col gap-6">
      <div className="flex items-start gap-4">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-muted">
          <Icon className="h-6 w-6 text-muted-foreground" aria-hidden />
        </div>
        <div className="flex flex-col gap-2 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <Badge variant="outline" className="capitalize">
              {LAB_TYPE_LABELS[lab.lab_type]}
            </Badge>
            <Badge variant="secondary">{lab.max_duration} min</Badge>
            <Badge variant="secondary">
              {lab.tasks.length} task{lab.tasks.length !== 1 ? "s" : ""}
            </Badge>
          </div>
          <h2 className="font-semibold text-lg leading-tight">{lab.title}</h2>
          {lab.description && (
            <p className="text-sm text-muted-foreground line-clamp-2">{lab.description}</p>
          )}
        </div>
      </div>

      <div className="flex items-center gap-4 text-sm text-muted-foreground">
        <span>Up to {lab.max_resets} reset{lab.max_resets !== 1 ? "s" : ""}</span>
        <span aria-hidden>·</span>
        <span>{lab.hint_penalty_pct}% hint penalty</span>
      </div>

      <Button
        size="lg"
        onClick={handleStart}
        disabled={isStarting}
        className={cn("w-full sm:w-auto")}
        aria-label={isStarting ? "Starting lab…" : `Start ${lab.title}`}
      >
        {isStarting ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden />
            Starting…
          </>
        ) : (
          "Start Lab"
        )}
      </Button>
    </div>
  )
}
