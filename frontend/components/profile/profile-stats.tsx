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
import { SettingsSection } from "@/components/profile/settings-section"
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

function StatCell({
  config,
  stats,
}: {
  config: StatConfig
  stats: Stats
}) {
  const Icon      = config.icon
  const soon      = config.comingSoon(stats)
  const isStreak  = config.label === "Current Streak"

  return (
    <div className="flex flex-col gap-1 bg-card p-4">
      <dt className="flex items-center gap-2 text-xs text-muted-foreground">
        <Icon
          aria-hidden="true"
          className={cn("shrink-0", isStreak && "text-primary")}
          size={14}
        />
        <span className="min-w-0 truncate">{config.label}</span>
      </dt>
      <dd
        className={cn(
          "flex flex-wrap items-center gap-x-2 gap-y-1 text-2xl font-bold tabular-nums",
          isStreak ? "text-primary" : soon ? "text-muted-foreground" : "text-foreground"
        )}
      >
        {config.value(stats)}
        {soon && (
          <Badge className="text-xs font-medium" variant="secondary">
            Coming soon
          </Badge>
        )}
      </dd>
    </div>
  )
}

export function ProfileStats({ stats }: Props) {
  return (
    <SettingsSection
      description="Lifetime totals across courses, tests and practice."
      id="profile-stats"
      title="Stats"
    >
      {stats ? (
        <dl className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-border bg-border sm:grid-cols-3">
          {STAT_CONFIGS.map((cfg) => (
            <StatCell config={cfg} key={cfg.label} stats={stats} />
          ))}
        </dl>
      ) : (
        <p className="text-sm text-muted-foreground">No stats yet — they appear after your first lesson or test.</p>
      )}
    </SettingsSection>
  )
}
