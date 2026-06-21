import { Check, Circle } from "lucide-react"
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

const CIRCUMFERENCE = 2 * Math.PI * 36 // ≈ 226.2

const CHECKLIST: { key: keyof Breakdown; label: string }[] = [
  { key: "avatar",       label: "Avatar" },
  { key: "bio",          label: "Bio" },
  { key: "skills",       label: "3+ Skills" },
  { key: "learningGoal", label: "Learning Goal" },
  { key: "domains",      label: "Domains" },
  { key: "socialLinks",  label: "Social Link" },
]

export function ProfileCompletion({ score, breakdown }: Props) {
  const pct    = Math.min(100, Math.max(0, score))
  const offset = CIRCUMFERENCE * (1 - pct / 100)

  return (
    <section aria-label="Profile completion" className="card-base p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="section-title text-lg">Profile Completion</h2>
        <span className="text-2xl font-bold text-primary">{pct}%</span>
      </div>

      <div className="flex flex-col items-center sm:flex-row sm:items-start gap-6">
        {/* SVG ring */}
        <div aria-hidden="true" className="shrink-0">
          <svg height="88" role="img" viewBox="0 0 88 88" width="88">
            <title>Profile completion: {pct}%</title>
            {/* Track */}
            <circle
              className="stroke-muted"
              cx="44"
              cy="44"
              fill="none"
              r="36"
              strokeWidth="8"
            />
            {/* Fill */}
            <circle
              className="stroke-primary transition-all duration-slow"
              cx="44"
              cy="44"
              fill="none"
              r="36"
              strokeDasharray={CIRCUMFERENCE}
              strokeDashoffset={offset}
              strokeLinecap="round"
              strokeWidth="8"
              transform="rotate(-90 44 44)"
            />
          </svg>
        </div>

        {/* Checklist */}
        <ul className="flex-1 grid grid-cols-1 gap-2 w-full">
          {CHECKLIST.map(({ key, label }) => {
            const done = breakdown[key]
            return (
              <li className="flex items-center gap-2" key={key}>
                {done ? (
                  <Check
                    aria-hidden="true"
                    className="text-primary shrink-0"
                    size={16}
                  />
                ) : (
                  <Circle
                    aria-hidden="true"
                    className="text-muted-foreground shrink-0"
                    size={16}
                  />
                )}
                <span
                  className={cn(
                    "text-sm",
                    done ? "text-foreground" : "text-muted-foreground"
                  )}
                >
                  {label}
                </span>
              </li>
            )
          })}
        </ul>
      </div>
    </section>
  )
}
