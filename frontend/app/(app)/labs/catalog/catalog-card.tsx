import { Clock } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { LabStartButton } from "@/components/labs/lab-start-button"
import { humanizeSlug } from "@/lib/labs/catalog-params"
import { LAB_TYPE_ICONS, LAB_TYPE_LABELS } from "@/lib/labs/lab-type-ui"
import type { LabCatalogEntry, LabCatalogStatus } from "@/lib/labs"

const STATUS_LABELS: Record<LabCatalogStatus, string> = {
  not_started: "Not started",
  in_progress: "In progress",
  completed: "Completed",
}

const STATUS_VARIANTS: Record<LabCatalogStatus, "outline" | "secondary" | "default"> = {
  not_started: "outline",
  in_progress: "secondary",
  completed: "default",
}

const START_LABELS: Record<LabCatalogStatus, string> = {
  not_started: "Start Lab",
  in_progress: "Resume Lab",
  completed: "Practice Again",
}

interface CatalogCardProps {
  entry: LabCatalogEntry
}

export function CatalogCard({ entry }: CatalogCardProps) {
  const Icon = LAB_TYPE_ICONS[entry.lab_type]

  return (
    <article className="card-base flex flex-col gap-4 p-6">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-muted">
            <Icon aria-hidden className="h-5 w-5 text-muted-foreground" />
          </div>
          <div className="flex min-w-0 flex-col gap-1">
            <h3 className="text-base font-semibold leading-snug">{entry.title}</h3>
            <p className="text-xs text-muted-foreground">
              {LAB_TYPE_LABELS[entry.lab_type]} · {humanizeSlug(entry.stack)} ·{" "}
              {humanizeSlug(entry.category)}
            </p>
          </div>
        </div>
        <Badge className="shrink-0" variant={STATUS_VARIANTS[entry.status]}>
          {STATUS_LABELS[entry.status]}
        </Badge>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <Badge className={`difficulty-${entry.difficulty}`} variant="outline">
          {humanizeSlug(entry.difficulty)}
        </Badge>
        <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
          <Clock aria-hidden className="h-3.5 w-3.5" />
          {entry.max_duration} min
        </span>
        {entry.skills.map((skill) => (
          <Badge key={skill} variant="secondary">
            {skill}
          </Badge>
        ))}
      </div>

      <LabStartButton
        lab={{ id: entry.lab_id, title: entry.title, lab_type: entry.lab_type }}
        label={START_LABELS[entry.status]}
      />
    </article>
  )
}
