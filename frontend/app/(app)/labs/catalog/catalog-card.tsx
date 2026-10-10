import Image from "next/image"
import { Clock } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { LabStartButton } from "@/components/labs/lab-start-button"
import { humanizeSlug } from "@/lib/labs/catalog-params"
import { stackImage } from "@/lib/labs/stack-images"
import type { LabCatalogEntry, LabCatalogStatus } from "@/lib/labs"

const START_LABELS: Record<LabCatalogStatus, string> = {
  not_started: "Start Lab",
  in_progress: "Resume Lab",
  completed: "Practice Again",
}

const MAX_SKILLS = 3

interface CatalogCardProps {
  entry: LabCatalogEntry
}

export function CatalogCard({ entry }: CatalogCardProps) {
  return (
    <article className="card-base flex h-full flex-col gap-4 p-4">
      <div className="flex items-start gap-3">
        <Image
          alt={`${humanizeSlug(entry.stack)} lab`}
          className="shrink-0 rounded-lg"
          height={48}
          sizes="48px"
          src={stackImage(entry.stack)}
          width={48}
        />
        <div className="flex min-w-0 flex-col gap-1">
          <h3 className="line-clamp-2 min-h-10 text-base font-semibold leading-5">{entry.title}</h3>
          <p className="flex items-center gap-2 text-xs text-muted-foreground">
            <span className={`difficulty-${entry.difficulty} rounded-sm border px-1.5 py-0.5`}>
              {humanizeSlug(entry.difficulty)}
            </span>
            <span className="inline-flex items-center gap-1">
              <Clock aria-hidden className="h-3.5 w-3.5" />
              {entry.max_duration} min
            </span>
          </p>
        </div>
      </div>
      <ul aria-label="Skills" className="flex min-h-6 flex-wrap gap-1.5">
        {entry.skills.slice(0, MAX_SKILLS).map((skill) => (
          <li key={skill}>
            <Badge variant="secondary">{skill}</Badge>
          </li>
        ))}
      </ul>
      <LabStartButton
        className="mt-auto sm:w-full"
        lab={{ id: entry.lab_id, title: entry.title, lab_type: entry.lab_type }}
        label={START_LABELS[entry.status]}
      />
    </article>
  )
}
