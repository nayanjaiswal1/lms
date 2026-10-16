import { Award, Trophy } from "lucide-react"
import { SettingsSection } from "@/components/profile/settings-section"
import { cn } from "@/lib/utils"
import type { Stats } from "@/lib/profile/types"
import type { UserAchievement } from "@/lib/server/rewards"

interface Props {
  stats: Stats | null
  achievements: UserAchievement[] | null
}

const TIER_RING: Record<UserAchievement["definition"]["badge_tier"], string> = {
  bronze:   "border-warning/40 bg-warning/10",
  silver:   "border-muted-foreground/40 bg-muted",
  gold:     "border-primary/40 bg-primary/10",
  platinum: "border-ai/40 bg-ai/10",
}

export function AchievementsCard({ stats, achievements }: Props) {
  const certCount = stats?.certificates_earned ?? 0
  const earned = achievements ?? []

  return (
    <SettingsSection
      action={
        <span className="inline-flex items-center gap-1.5 text-sm text-muted-foreground">
          <Award aria-hidden="true" className={cn("h-4 w-4", certCount > 0 && "text-primary")} />
          {certCount} {certCount === 1 ? "certificate" : "certificates"}
        </span>
      }
      description="Badges you've earned. Certificates come from finishing a course and passing its final test."
      id="achievements"
      title="Achievements"
    >
      {earned.length > 0 ? (
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {earned.map((achievement) => (
            <li
              className={cn(
                "flex flex-col items-center gap-1.5 rounded-lg border p-4 text-center",
                TIER_RING[achievement.definition.badge_tier]
              )}
              key={achievement.id}
              title={achievement.definition.description}
            >
              <span aria-hidden="true" className="text-2xl">
                {achievement.definition.icon}
              </span>
              <p className="text-xs font-semibold leading-tight text-foreground">
                {achievement.definition.name}
              </p>
              <p className="text-xs capitalize text-muted-foreground">{achievement.definition.badge_tier}</p>
            </li>
          ))}
        </ul>
      ) : (
        <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-border px-4 py-8 text-center">
          <Trophy aria-hidden="true" className="h-6 w-6 text-muted-foreground" />
          <p className="text-sm font-medium text-foreground">No badges yet</p>
          <p className="max-w-xs text-sm text-muted-foreground">
            Solve problems, pass tests and complete courses to earn your first one.
          </p>
        </div>
      )}
    </SettingsSection>
  )
}
