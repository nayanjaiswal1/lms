import { ProfileSidebar } from '@/components/profile/profile-sidebar'
import { DifficultySolvedChart } from '@/components/profile/difficulty-solved-chart'
import { SubmissionActivityCalendar } from '@/components/profile/submission-activity-calendar'
import { RecentSubmissionsList } from '@/components/profile/recent-submissions-list'
import { AchievementsCard } from '@/components/profile/achievements-card'
import type { Profile, ProfileOverview as ProfileOverviewData } from '@/lib/profile/types'
import type { MyRankResponse, UserRewardProfile } from '@/lib/server/rewards'

interface Props {
  profile: Profile
  overview: ProfileOverviewData | null
  rewardProfile: UserRewardProfile | null
  rank: MyRankResponse | null
}

export function ProfileOverview({ profile, overview, rewardProfile, rank }: Props) {
  return (
    <div className="flex flex-col gap-6 lg:flex-row lg:items-start">
      <ProfileSidebar overview={overview} profile={profile} rank={rank} rewardProfile={rewardProfile} />

      <div className="flex-1 min-w-0 space-y-6">
        {overview ? (
          <>
            <DifficultySolvedChart
              attempting={overview.attempting}
              difficulty={overview.difficulty}
              solvedTotal={overview.solved_total}
            />
            <SubmissionActivityCalendar
              activeDays={overview.active_days}
              calendar={overview.calendar}
              maxStreak={overview.max_streak}
              totalSubmissions={overview.total_submissions}
            />
            <AchievementsCard achievements={rewardProfile?.achievements ?? null} stats={profile.stats} />
            <RecentSubmissionsList items={overview.recent_activity} />
          </>
        ) : (
          <div className="card-base p-6">
            <p className="text-sm text-muted-foreground">
              Activity data isn&apos;t available right now. Try refreshing the page.
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
