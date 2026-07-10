import Link from 'next/link'
import { CalendarDays, Code2, Flame, Pencil } from 'lucide-react'
import { ProfileAvatar } from '@/components/shared/profile-avatar'
import { XPProgressBar } from '@/components/rewards/xp-progress-bar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import ROUTES from '@/lib/routes'
import type { Profile, ProfileOverview } from '@/lib/profile/types'
import type { MyRankResponse, UserRewardProfile } from '@/lib/server/rewards'

interface Props {
  profile: Profile
  overview: ProfileOverview | null
  rewardProfile: UserRewardProfile | null
  rank: MyRankResponse | null
}

const SKILL_LEVEL_ORDER = ['advanced', 'intermediate', 'beginner'] as const
const SKILL_LEVEL_DOT: Record<(typeof SKILL_LEVEL_ORDER)[number], string> = {
  advanced:     'bg-primary',
  intermediate: 'bg-warning',
  beginner:     'bg-success',
}

export function ProfileSummaryCard({ profile, overview, rewardProfile, rank }: Props) {
  const orderedSkills = SKILL_LEVEL_ORDER.flatMap((level) =>
    profile.skills.filter((s) => s.skill_level === level).map((s) => ({ ...s, level })),
  )

  return (
    <section aria-label="Profile summary" className="card-base p-6 space-y-5">
      <div className="flex flex-col items-center text-center gap-3">
        <ProfileAvatar avatarUrl={profile.avatar_url} name={profile.name} size="md" />

        <div className="min-w-0 w-full">
          <h1 className="text-lg font-bold text-foreground truncate">{profile.name}</h1>
          {profile.display_name && (
            <p className="text-sm text-muted-foreground truncate">@{profile.display_name}</p>
          )}
          {rank && rank.rank > 0 && (
            <p className="text-sm text-muted-foreground mt-1">
              Rank <span className="font-semibold text-foreground">{rank.rank.toLocaleString()}</span>
            </p>
          )}
        </div>

        <Button asChild className="gap-1.5 w-full" size="sm">
          <Link href={`${ROUTES.SETTINGS_PROFILE}?tab=profile`}>
            <Pencil aria-hidden="true" size={14} />
            Edit Profile
          </Link>
        </Button>
      </div>

      {rewardProfile && (
        <div className="pt-4 border-t border-border">
          <XPProgressBar level={rewardProfile.level} totalXP={rewardProfile.total_xp} />
        </div>
      )}

      {overview && (
        <div className="space-y-2.5 pt-4 border-t border-border">
          <p className="flex items-center gap-2 text-sm text-muted-foreground">
            <Code2 aria-hidden="true" size={16} />
            Solved
            <span className="ml-auto font-semibold text-foreground tabular-nums">{overview.solved_total}</span>
          </p>
          <p className="flex items-center gap-2 text-sm text-muted-foreground">
            <CalendarDays aria-hidden="true" size={16} />
            Active days
            <span className="ml-auto font-semibold text-foreground tabular-nums">{overview.active_days}</span>
          </p>
          <p className="flex items-center gap-2 text-sm text-muted-foreground">
            <Flame aria-hidden="true" size={16} />
            Max streak
            <span className="ml-auto font-semibold text-foreground tabular-nums">{overview.max_streak}</span>
          </p>
        </div>
      )}

      {orderedSkills.length > 0 && (
        <div className="flex flex-wrap gap-1.5 pt-4 border-t border-border">
          {orderedSkills.map((skill) => (
            <Badge className="gap-1.5" key={skill.id} variant="secondary">
              <span aria-hidden="true" className={`h-1.5 w-1.5 rounded-full ${SKILL_LEVEL_DOT[skill.level]}`} />
              {skill.skill_name}
            </Badge>
          ))}
        </div>
      )}
    </section>
  )
}
