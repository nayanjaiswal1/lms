"use client"

import { Badge } from "@/components/ui/badge"
import { LabStartButton } from "@/components/labs/lab-start-button"
import { LAB_TYPE_ICONS, LAB_TYPE_LABELS } from "@/lib/labs/lab-type-ui"
import type { Lab } from "@/lib/labs"

interface LabLauncherProps {
  lab: Lab
}

export function LabLauncher({ lab }: LabLauncherProps) {
  const Icon = LAB_TYPE_ICONS[lab.lab_type]

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

      <LabStartButton lab={lab} label="Start Lab" />
    </div>
  )
}
