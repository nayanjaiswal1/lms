import {
  ClipboardCheck,
  CheckCircle,
  BookOpen,
  GraduationCap,
  Code,
  Award,
  Clock,
  Flame,
  Map,
} from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import type { Stats } from "@/lib/profile/types"

interface Props {
  stats: Stats | null
}

interface StatConfig {
  label: string
  value: (s: Stats) => string
  icon: React.ComponentType<{ size?: number; className?: string }>
  comingSoon: (s: Stats) => boolean
}

function fmtHours(h: number): string {
  return `${h.toFixed(1)} hrs`
}

function fmtStreak(days: number): string {
  return `${days} ${days === 1 ? "day" : "days"}`
}

const STAT_CONFIGS: StatConfig[] = [
  {
    label:      "Tests Attempted",
    icon:       ClipboardCheck,
    value:      (s) => String(s.tests_attempted),
    comingSoon: () => false,
  },
  {
    label:      "Tests Passed",
    icon:       CheckCircle,
    value:      (s) => String(s.tests_passed),
    comingSoon: () => false,
  },
  {
    label:      "Courses Enrolled",
    icon:       BookOpen,
    value:      (s) => String(s.courses_enrolled),
    comingSoon: (s) => s.courses_enrolled === 0,
  },
  {
    label:      "Courses Completed",
    icon:       GraduationCap,
    value:      (s) => String(s.courses_completed),
    comingSoon: (s) => s.courses_completed === 0,
  },
  {
    label:      "Problems Solved",
    icon:       Code,
    value:      (s) => String(s.problems_solved),
    comingSoon: (s) => s.problems_solved === 0,
  },
  {
    label:      "Certificates",
    icon:       Award,
    value:      (s) => String(s.certificates_earned),
    comingSoon: () => false,
  },
  {
    label:      "Learning Hours",
    icon:       Clock,
    value:      (s) => fmtHours(s.learning_hours),
    comingSoon: () => false,
  },
  {
    label:      "Current Streak",
    icon:       Flame,
    value:      (s) => fmtStreak(s.current_streak_days),
    comingSoon: () => false,
  },
  {
    label:      "Roadmaps",
    icon:       Map,
    value:      (s) => String(s.roadmaps_completed),
    comingSoon: (s) => s.roadmaps_completed === 0,
  },
]

function StatCard({
  config,
  stats,
}: {
  config: StatConfig
  stats: Stats
}) {
  const Icon      = config.icon
  const soon      = config.comingSoon(stats)
  const displayed = config.value(stats)
  const isStreak  = config.label === "Current Streak"

  return (
    <div
      className={cn(
        "card-base p-4 flex flex-col gap-2",
        soon && "opacity-50"
      )}
    >
      <div className="flex items-center justify-between">
        <Icon
          aria-hidden="true"
          className={cn(isStreak ? "text-primary" : "text-muted-foreground")}
          size={18}
        />
        {soon && (
          <Badge className="text-xs" variant="secondary">
            Coming soon
          </Badge>
        )}
      </div>
      <p
        className={cn(
          "text-2xl font-bold",
          isStreak && "text-primary"
        )}
      >
        {displayed}
      </p>
      <p className="text-xs text-muted-foreground">{config.label}</p>
    </div>
  )
}

export function ProfileStats({ stats }: Props) {
  if (!stats) {
    return (
      <section aria-label="Learning stats" className="card-base p-6">
        <h2 className="section-title text-lg mb-4">Stats</h2>
        <p className="text-sm text-muted-foreground">No stats available yet.</p>
      </section>
    )
  }

  return (
    <section aria-label="Learning stats" className="card-base p-6">
      <h2 className="section-title text-lg mb-4">Stats</h2>
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        {STAT_CONFIGS.map((cfg) => (
          <StatCard config={cfg} key={cfg.label} stats={stats} />
        ))}
      </div>
    </section>
  )
}
