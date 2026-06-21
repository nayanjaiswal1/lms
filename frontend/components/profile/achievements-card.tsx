import { Award, Lock, Trophy } from "lucide-react"
import type { Stats } from "@/lib/profile/types"

interface Props {
  stats: Stats | null
}

function ComingSoonSection({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-3 p-4 rounded-lg bg-muted opacity-50">
      <Lock aria-hidden="true" className="text-muted-foreground shrink-0" size={16} />
      <div>
        <p className="text-sm font-medium text-foreground">{label}</p>
        <p className="text-xs text-muted-foreground">Unlocks when feature launches</p>
      </div>
    </div>
  )
}

export function AchievementsCard({ stats }: Props) {
  const certCount = stats?.certificates_earned ?? 0

  return (
    <section aria-label="Achievements" className="card-base p-6">
      <h2 className="section-title text-lg mb-4">Achievements</h2>

      <div className="space-y-4">
        {/* Top Skills — coming soon */}
        <div>
          <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-2">
            Top Skills
          </h3>
          <ComingSoonSection label="Skill rankings" />
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

        {/* Leaderboard — coming soon */}
        <div>
          <h3 className="text-sm font-medium text-muted-foreground uppercase tracking-wide mb-2">
            Leaderboard
          </h3>
          <ComingSoonSection label="Leaderboard ranking" />
        </div>

        {/* Trophy placeholder for future */}
        <div className="flex items-center gap-2 pt-2 opacity-40">
          <Trophy aria-hidden="true" className="text-muted-foreground" size={14} />
          <p className="text-xs text-muted-foreground">
            More achievements coming soon
          </p>
        </div>
      </div>
    </section>
  )
}
