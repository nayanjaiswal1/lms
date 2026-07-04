import Link from 'next/link'
import { Pencil } from 'lucide-react'
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
const SKILL_LEVEL_LABEL: Record<(typeof SKILL_LEVEL_ORDER)[number], string> = {
  advanced:     'Advanced',
  intermediate: 'Intermediate',
  beginner:     'Beginner',
}

export function ProfileSidebar({ profile, overview, rewardProfile, rank }: Props) {
  const groupedSkills = SKILL_LEVEL_ORDER.map((level) => ({
    level,
    skills: profile.skills.filter((s) => s.skill_level === level),
  })).filter((g) => g.skills.length > 0)

  return (
    <aside className="w-full lg:w-[280px] shrink-0 space-y-4">
      <div className="card-base p-6 flex flex-col items-center text-center gap-3">
        <ProfileAvatar avatarUrl={profile.avatar_url} name={profile.name} size="lg" />

        <div>
          <h1 className="text-lg font-bold text-foreground truncate max-w-full">{profile.name}</h1>
          {profile.display_name && (
            <p className="text-sm text-muted-foreground">@{profile.display_name}</p>
          )}
        </div>

        {rank && rank.rank > 0 && (
          <Badge variant="secondary">Rank #{rank.rank.toLocaleString()}</Badge>
        )}

        {rewardProfile && (
          <XPProgressBar className="w-full" level={rewardProfile.level} totalXP={rewardProfile.total_xp} />
        )}

        <Button asChild className="w-full gap-1.5" size="sm" variant="outline">
          <Link href={`${ROUTES.SETTINGS_PROFILE}?tab=profile`}>
            <Pencil aria-hidden="true" size={14} />
            Edit Profile
          </Link>
        </Button>
      </div>

      {overview && (
        <section aria-label="Community stats" className="card-base p-6 space-y-3">
          <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wide">
            Community Stats
          </h2>
          <dl className="grid grid-cols-3 gap-2 text-center">
            <div>
              <dt className="text-xs text-muted-foreground">Solved</dt>
              <dd className="text-lg font-bold text-foreground tabular-nums">{overview.solved_total}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">Active days</dt>
              <dd className="text-lg font-bold text-foreground tabular-nums">{overview.active_days}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">Max streak</dt>
              <dd className="text-lg font-bold text-foreground tabular-nums">{overview.max_streak}</dd>
            </div>
          </dl>
        </section>
      )}

      {groupedSkills.length > 0 && (
        <section aria-label="Skills" className="card-base p-6 space-y-3">
          <h2 className="text-sm font-medium text-muted-foreground uppercase tracking-wide">
            Skills
          </h2>
          {groupedSkills.map((group) => (
            <div key={group.level}>
              <p className="text-xs text-muted-foreground mb-1.5">
                {SKILL_LEVEL_LABEL[group.level]}
                <span className="ml-1">({group.skills.length})</span>
              </p>
              <div className="flex flex-wrap gap-1.5">
                {group.skills.map((skill) => (
                  <Badge key={skill.id} variant="secondary">
                    {skill.skill_name}
                  </Badge>
                ))}
              </div>
            </div>
          ))}
        </section>
      )}
    </aside>
  )
}
