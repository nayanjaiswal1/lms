import { redirect } from 'next/navigation'
import Link from 'next/link'
import { NextPageLink } from "@/components/shared/next-page-link";
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
        className="-ml-2 inline-flex min-h-11 items-center gap-1.5 rounded-md px-2 text-sm text-muted-foreground transition-colors duration-fast hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        href={ROUTES.SETTINGS_PROFILE}
      >
        <ArrowLeft aria-hidden="true" size={16} />
        Back to profile overview
      </Link>

      <ProfileHeader profile={profile} uploadAction={uploadAvatarAction} />

      <ProfileCompletion
        breakdown={breakdown}
        score={profile.completion_score}
      />

      <nav aria-label="Profile settings sections" className="border-b border-border">
        <ul className="-mb-px flex overflow-x-auto">
          {EDIT_TABS.map((tab) => {
            const isActive = tab.key === activeTab
            return (
              <li className="shrink-0" key={tab.key}>
                <Link
                  aria-current={isActive ? 'page' : undefined}
                  className={cn(
                    'flex min-h-11 items-center whitespace-nowrap border-b-2 px-4 text-sm font-medium',
                    'transition-colors duration-fast ease-smooth focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring',
                    isActive
                      ? 'border-primary text-foreground'
                      : 'border-transparent text-muted-foreground hover:border-border hover:text-foreground'
                  )}
                  href={`?tab=${tab.key}`}
                >
                  {tab.label}
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>

      <div className="space-y-6">
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

        {activeTab === 'activity' && (
          <>
            <AchievementsCard achievements={rewardProfile?.achievements ?? null} stats={profile.stats} />
            <ProfileStats stats={profile.stats} />
            {activityPage && (
              activityPage.entries.length === 0 ? (
                <div className="card-base empty-state p-6">
                  <History aria-hidden="true" className="empty-state-icon" />
                  <div className="space-y-1">
                    <p className="font-medium text-foreground">Nothing tracked yet</p>
                    <p className="text-sm">Complete a module or review a card and it shows up here.</p>
                  </div>
                </div>
              ) : (
                <>
                  <ActivityTimeline entries={activityPage.entries} />
                  <NextPageLink nextCursor={activityPage.next_cursor} searchParams={{ tab: "activity" }} />
                </>
              )
            )}
          </>
        )}
      </div>
    </div>
  )
}
