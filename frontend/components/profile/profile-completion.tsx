import { Check, ChevronDown, PartyPopper } from "lucide-react"
import { cn } from "@/lib/utils"

interface Breakdown {
  avatar: boolean
  bio: boolean
  skills: boolean
  learningGoal: boolean
  domains: boolean
  socialLinks: boolean
}

interface Props {
  score: number
  breakdown: Breakdown
}

const CHECKLIST: { key: keyof Breakdown; label: string; hint: string }[] = [
  { key: "avatar",       label: "Add a photo",         hint: "Profile tab, header" },
  { key: "bio",          label: "Write a short bio",   hint: "Basic information" },
  { key: "skills",       label: "List 3+ skills",      hint: "Skills" },
  { key: "learningGoal", label: "Set a learning goal", hint: "Preferences tab" },
  { key: "domains",      label: "Pick a domain",       hint: "Preferences tab" },
  { key: "socialLinks",  label: "Link a profile",      hint: "Social links" },
]

export function ProfileCompletion({ score, breakdown }: Props) {
  const pct = Math.min(100, Math.max(0, score))
  const remaining = CHECKLIST.filter(({ key }) => !breakdown[key]).length

  if (remaining === 0) {
    return (
      <section aria-label="Profile completion" className="card-base flex items-center gap-3 p-6">
        <PartyPopper aria-hidden="true" className="h-5 w-5 shrink-0 text-primary" />
        <p className="text-sm text-foreground">Your profile is complete — nice work.</p>
      </section>
    )
  }

  // Native <details>: the checklist stays one tap away without pushing the
  // forms below the fold on mobile.
  return (
    <details className="card-base group p-0">
      <summary className="flex min-h-11 cursor-pointer list-none flex-wrap items-center justify-between gap-x-3 gap-y-1 rounded-lg p-6 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring [&::-webkit-details-marker]:hidden">
        <span className="subsection-title text-foreground">Finish your profile</span>
        <span className="flex items-center gap-2 text-sm text-muted-foreground">
          <span className="font-semibold text-primary">{pct}%</span>
          <span aria-hidden="true">·</span>
          {remaining} {remaining === 1 ? "step" : "steps"} left
          <ChevronDown
            aria-hidden="true"
            className="h-4 w-4 shrink-0 transition-transform duration-fast group-open:rotate-180"
          />
        </span>
      </summary>

      <ul className="grid gap-x-6 gap-y-1 px-6 pb-6 sm:grid-cols-2 lg:grid-cols-3">
        {CHECKLIST.map(({ key, label, hint }) => {
          const done = breakdown[key]
          return (
            <li className="flex items-start gap-3 py-1.5" key={key}>
              <span
                aria-hidden="true"
                className={cn(
                  "mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border",
                  done ? "border-primary bg-primary text-primary-foreground" : "border-border"
                )}
              >
                {done && <Check className="h-3 w-3" strokeWidth={3} />}
              </span>
              <span className="min-w-0">
                <span className={cn("block text-sm", done ? "text-muted-foreground line-through" : "font-medium text-foreground")}>
                  {label}
                  <span className="sr-only">{done ? " (done)" : " (to do)"}</span>
                </span>
                {!done && <span className="block text-xs text-muted-foreground">{hint}</span>}
              </span>
            </li>
          )
        })}
      </ul>
    </details>
  )
}
