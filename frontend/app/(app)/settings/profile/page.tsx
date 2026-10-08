import { redirect } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, History } from 'lucide-react'
import { fetchMyOverview, fetchMyProfile } from '@/lib/profile/server'
import { getMyRank, getMyRewardProfile } from '@/lib/server/rewards'
import { getMyBatches } from '@/lib/server/batches'
import { getActivity } from '@/lib/server/activity'
import { ActivityTimeline } from '@/components/activity/activity-timeline'
import ROUTES from '@/lib/routes'
import { ProfileHeader } from '@/components/profile/profile-header'
import { ProfileOverview } from '@/components/profile/profile-overview'
import { ProfileCompletion } from '@/components/profile/profile-completion'
import { ProfileStats } from '@/components/profile/profile-stats'
import { SkillsManager } from '@/components/profile/skills-manager'
import { LearningPreferences } from '@/components/profile/learning-preferences'
import { AchievementsCard } from '@/components/profile/achievements-card'
import { SocialLinksForm } from '@/components/profile/social-links-form'
import { PreferencesForm } from '@/components/profile/preferences-form'
import { AppearanceSection } from '@/components/profile/appearance-section'
import { KnowledgeCheckToggle } from '@/components/courses/knowledge-check-toggle'
import { ResumeUpload } from '@/components/profile/resume-upload'
import { BasicInfoForm } from './_components/basic-info-form'
import {
  updateBasicInfoAction,
  updateLearningAction,
  updateSocialLinksAction,
  updatePreferencesAction,
  addSkillAction,
  removeSkillAction,
  uploadAvatarAction,
  parseResumeAction,
  applyResumeAction,
} from './actions'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

const EDIT_TABS = [
  { key: 'profile',     label: 'Profile' },
  { key: 'preferences', label: 'Preferences' },
  { key: 'activity',    label: 'Activity' },
] as const

const TABS = [{ key: 'overview', label: 'Overview' }, ...EDIT_TABS] as const

type TabKey = typeof TABS[number]['key']

// Tabs that were folded into the three above — keeps old links working.
const LEGACY_TABS: Record<string, TabKey> = {
  skills:       'profile',
  learning:     'preferences',
  achievements: 'activity',
}

export default async function SettingsProfilePage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; cursor?: string }>
}) {
  const profile = await fetchMyProfile()
  if (!profile) redirect(ROUTES.LOGIN)

  const { tab: rawTab, cursor } = await searchParams
  const activeTab: TabKey =
    TABS.find((t) => t.key === rawTab)?.key ?? LEGACY_TABS[rawTab ?? ''] ?? 'overview'

  const rewardProfile = await getMyRewardProfile()

  const [overview, rank, batches] = activeTab === 'overview'
    ? await Promise.all([fetchMyOverview(), getMyRank('global'), getMyBatches()])
    : [null, null, []]

  const activityPage = activeTab === 'activity' ? await getActivity({ cursor }) : null

  const breakdown = {
    avatar: profile.avatar_url !== null,
    bio: Boolean(profile.bio),
    skills: profile.skills.length >= 3,
    learningGoal: profile.learning_goal !== null,
    domains: (profile.topics_interest?.length ?? 0) >= 1,
    socialLinks: Boolean(
      profile.social_links?.linkedin ||
      profile.social_links?.github ||
      profile.social_links?.portfolio
    ),
  }

  if (activeTab === 'overview') {
    return (
      <ProfileOverview
        batches={batches}
        overview={overview}
        profile={profile}
        rank={rank}
        rewardProfile={rewardProfile}
      />
    )
  }

  return (
    <div className="space-y-6">
      <Link
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors duration-fast"
        href={ROUTES.SETTINGS_PROFILE}
      >
        <ArrowLeft aria-hidden="true" size={14} />
        Back to profile
      </Link>

      <ProfileHeader profile={profile} uploadAction={uploadAvatarAction} />

      <div
        aria-label="Profile settings sections"
        className="flex overflow-x-auto gap-0 border-b border-border -mb-px"
        role="tablist"
      >
        {EDIT_TABS.map((tab) => {
          const isActive = tab.key === activeTab
          return (
            <Link
              aria-selected={isActive}
              className={cn(
                'flex-shrink-0 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors duration-[--duration-fast] whitespace-nowrap',
                isActive
                  ? 'text-primary border-primary'
                  : 'text-muted-foreground border-transparent hover:text-foreground hover:border-border'
              )}
              href={`?tab=${tab.key}`}
              key={tab.key}
              role="tab"
            >
              {tab.label}
            </Link>
          )
        })}
      </div>

      <div className="flex flex-col gap-6 lg:flex-row lg:items-start">
        <div className="flex-1 min-w-0 space-y-6">
          {activeTab === 'profile' && (
            <>
              <BasicInfoForm
                profile={profile}
                updateAction={updateBasicInfoAction}
              />
              <SocialLinksForm
                socialLinks={profile.social_links}
                updateAction={updateSocialLinksAction}
              />
              <SkillsManager
                addAction={addSkillAction}
                removeAction={removeSkillAction}
                skills={profile.skills}
              />
              <ResumeUpload
                applyAction={applyResumeAction}
                parseAction={parseResumeAction}
              />
            </>
          )}




          {activeTab === 'activity' && (
            <>
              <AchievementsCard achievements={rewardProfile?.achievements ?? null} stats={profile.stats} />
              <ProfileStats stats={profile.stats} />
            </>
          )}

          {activeTab === 'activity' && activityPage && (
            activityPage.entries.length === 0 ? (
              <div className="empty-state">
                <History aria-hidden className="h-10 w-10 text-muted-foreground" />
                <p className="text-muted-foreground">Nothing tracked yet — complete a module or review a card to see it here.</p>
              </div>
            ) : (
              <>
                <ActivityTimeline entries={activityPage.entries} />

                {activityPage.next_cursor && (
                  <div className="flex justify-center pt-4">
                    <Button asChild variant="secondary">
                      <Link href={`?tab=activity&cursor=${encodeURIComponent(activityPage.next_cursor)}`}>Load more</Link>
                    </Button>
                  </div>
                )}
              </>
            )
          )}

          {activeTab === 'preferences' && (
            <>
              <LearningPreferences
                profile={profile}
                updateAction={updateLearningAction}
              />
              <PreferencesForm
                profile={profile}
                updateAction={updatePreferencesAction}
              />
              <AppearanceSection />
              <KnowledgeCheckToggle />
            </>
          )}
        </div>

        <aside className="w-full lg:w-[260px] flex-shrink-0">
          <ProfileCompletion
            breakdown={breakdown}
            score={profile.completion_score}
          />
        </aside>
      </div>
    </div>
  )
}

