import { Award, Trophy } from "lucide-react"
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
    <section aria-label="Achievements" className="card-base p-6">
      <h2 className="section-title mb-4">Achievements</h2>

      <div className="space-y-4">
        {/* Badges — real earned achievements from the rewards domain */}
        <div>
          <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-2">
            Badges
          </h3>
          {earned.length > 0 ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {earned.map((achievement) => (
                <div
                  className={cn(
                    "flex flex-col items-center gap-1.5 p-3 rounded-lg border text-center",
                    TIER_RING[achievement.definition.badge_tier]
                  )}
                  key={achievement.id}
                  title={achievement.definition.description}
                >
                  <span aria-hidden="true" className="text-2xl">
                    {achievement.definition.icon}
                  </span>
                  <p className="text-xs font-semibold text-foreground leading-tight">
                    {achievement.definition.name}
                  </p>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center gap-2 py-6 text-center">
              <Trophy aria-hidden="true" className="text-muted-foreground" size={32} />
              <p className="text-sm text-muted-foreground max-w-56">
                Solve problems, pass tests, and complete courses to earn badges.
              </p>
            </div>
          )}
        </div>

        {/* Certificates */}
        <div>
          <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-2">
            Certificates
          </h3>
          {certCount > 0 ? (
            <div className="flex items-center gap-3 p-4 rounded-lg bg-muted">
              <Award aria-hidden="true" className="text-primary shrink-0" size={20} />
              <div>
                <p className="text-sm font-semibold text-foreground">
                  {certCount} {certCount === 1 ? "Certificate" : "Certificates"} earned
                </p>
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-2 py-6 text-center">
              <Award
                aria-hidden="true"
                className="text-muted-foreground"
                size={32}
              />
              <p className="text-sm text-muted-foreground max-w-56">
                Complete courses and assessments to earn certificates.
              </p>
            </div>
          )}
        </div>
      </div>
    </section>
  )
}
