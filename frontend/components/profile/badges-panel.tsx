import { Lock } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { UserAchievement } from '@/lib/server/rewards'

interface Props {
  achievements: UserAchievement[] | null
}

const TIER_RING: Record<UserAchievement['definition']['badge_tier'], string> = {
  bronze:   'border-warning/40 bg-warning/10',
  silver:   'border-muted-foreground/40 bg-muted',
  gold:     'border-primary/40 bg-primary/10',
  platinum: 'border-ai/40 bg-ai/10',
}

const GALLERY_SIZE = 6

export function BadgesPanel({ achievements }: Props) {
  const earned = achievements ?? []
  const lockedSlots = Math.max(0, GALLERY_SIZE - earned.length)

  return (
    <section aria-label="Badges" className="card-base p-6 w-full sm:w-64 shrink-0">
      <div className="flex items-baseline justify-between mb-4">
        <h2 className="text-sm font-semibold text-foreground">Badges</h2>
        <span className="text-lg font-bold text-foreground tabular-nums">{earned.length}</span>
      </div>

      <div className="grid grid-cols-3 gap-2">
        {earned.slice(0, GALLERY_SIZE).map((achievement) => (
          <div
            className={cn(
              'flex flex-col items-center justify-center gap-1 aspect-square rounded-lg border p-2 text-center',
              TIER_RING[achievement.definition.badge_tier],
            )}
            key={achievement.id}
            title={achievement.definition.description}
          >
            <span aria-hidden="true" className="text-xl">{achievement.definition.icon}</span>
          </div>
        ))}
        {Array.from({ length: lockedSlots }).map((_, i) => (
          <div
            aria-hidden="true"
            className="flex items-center justify-center aspect-square rounded-lg border border-dashed border-border bg-muted/40"
            key={`locked-${i}`}
          >
            <Lock className="text-muted-foreground/60" size={16} />
          </div>
        ))}
      </div>
    </section>
  )
}
