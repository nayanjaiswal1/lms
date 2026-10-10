import Image from "next/image"
import Link from "next/link"
import { CheckCircle2, Clock } from "lucide-react"
import { LabStartButton } from "@/components/labs/lab-start-button"
import { displayTitle, distinctSkills, humanizeSlug } from "@/lib/labs/catalog-params"
import { stackImage } from "@/lib/labs/stack-images"
import ROUTES from "@/lib/routes"
import type { LabCatalogEntry } from "@/lib/labs"

interface CatalogCardProps {
  entry: LabCatalogEntry
}

function StatusLabel({ entry }: CatalogCardProps) {
  if (entry.status === "completed") {
    return (
      <span className="inline-flex items-center gap-1 text-xs font-medium text-success">
        <CheckCircle2 aria-hidden className="h-3.5 w-3.5" />
        Passed{typeof entry.best_score === "number" && ` · ${entry.best_score}`}
      </span>
    )
  }
  if (entry.status === "in_progress") {
    return <span className="text-xs font-medium text-primary">In progress</span>
  }
  return <span className="text-xs text-muted-foreground">Not started</span>
}

/** The title link stretches over the card, so the whole card is one click target; the action sits above it. */
export function CatalogCard({ entry }: CatalogCardProps) {
  const title = displayTitle(entry.title)
  const skills = distinctSkills(entry.skills)
  const isActive = entry.status === "in_progress"

  return (
    <article className="card-interactive relative flex h-full flex-col gap-3 p-4 focus-within:ring-2 focus-within:ring-ring">
      <div className="flex items-start gap-3">
        <Image
          alt=""
          className="shrink-0 rounded-md"
          height={36}
          sizes="36px"
          src={stackImage(entry.stack)}
          width={36}
        />
        <h3 className="line-clamp-3 min-w-0 text-sm font-semibold leading-5">
          <Link
            className="text-foreground outline-none after:absolute after:inset-0 after:content-['']"
            href={ROUTES.lab(entry.lab_id)}
          >
            {title}
          </Link>
        </h3>
      </div>
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
        <span className={`difficulty-${entry.difficulty} rounded-sm border px-1.5 py-0.5 font-medium`}>
          {humanizeSlug(entry.difficulty)}
        </span>
        <span className="inline-flex items-center gap-1">
          <Clock aria-hidden className="h-3.5 w-3.5" />
          {entry.max_duration} min
        </span>
        {skills.length > 0 && <span className="min-w-0 truncate">{skills.join(", ")}</span>}
      </div>
      <div className="mt-auto flex items-center justify-between gap-2 pt-1">
        <StatusLabel entry={entry} />
        <LabStartButton
          className="relative z-raised w-auto"
          idleVariant="ghost"
          lab={{ id: entry.lab_id, title: entry.title, lab_type: entry.lab_type }}
          label={isActive ? "Resume" : entry.status === "completed" ? "Practice again" : "Start"}
          size="sm"
        />
      </div>
    </article>
  )
}
