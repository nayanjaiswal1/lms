import { ProfileSummaryCard } from '@/components/profile/profile-summary-card'
import { LanguageStatsCard } from '@/components/profile/language-stats-card'
import { CoursesSummaryCard } from '@/components/profile/courses-summary-card'
import { BatchesSummaryCard } from '@/components/profile/batches-summary-card'
import { DifficultySolvedChart } from '@/components/profile/difficulty-solved-chart'
import { BadgesPanel } from '@/components/profile/badges-panel'
import { SubmissionActivityCalendar } from '@/components/profile/submission-activity-calendar'
import { RecentSubmissionsList } from '@/components/profile/recent-submissions-list'
import type { Profile, ProfileOverview as ProfileOverviewData } from '@/lib/profile/types'
import type { MyRankResponse, UserRewardProfile } from '@/lib/server/rewards'
import type { MyBatch } from '@/lib/server/batches'

interface Props {
  profile: Profile
  overview: ProfileOverviewData | null
  rewardProfile: UserRewardProfile | null
  rank: MyRankResponse | null
  batches: MyBatch[]
}

export function ProfileOverview({ profile, overview, rewardProfile, rank, batches }: Props) {
  return (
    <div className="flex flex-col gap-6 lg:flex-row lg:items-start">
      <aside className="w-full lg:w-[280px] flex-shrink-0 space-y-6">
        <ProfileSummaryCard overview={overview} profile={profile} rank={rank} rewardProfile={rewardProfile} />
        {overview && <LanguageStatsCard languages={overview.language_stats} />}
      </aside>

      <div className="flex-1 min-w-0 space-y-6">
        {overview ? (
          <>
            <div className="flex flex-col gap-6 sm:flex-row">
              <DifficultySolvedChart
                attempting={overview.attempting}
                difficulty={overview.difficulty}
                solvedTotal={overview.solved_total}
              />
              <BadgesPanel achievements={rewardProfile?.achievements ?? null} />
            </div>
            <div className="grid grid-cols-1 items-start gap-6 sm:grid-cols-2">
              <CoursesSummaryCard stats={profile.stats} />
              <BatchesSummaryCard batches={batches} />
            </div>
            <SubmissionActivityCalendar
              activeDays={overview.active_days}
              calendar={overview.calendar}
              maxStreak={overview.max_streak}
              totalSubmissions={overview.total_submissions}
            />
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
