import { redirect } from 'next/navigation'
import Link from 'next/link'
import { fetchMyProfile } from '@/lib/server/profile'
import type { Profile } from '@/lib/profile/types'
import ROUTES from '@/lib/routes'
import { ProfileHeader } from '@/components/profile/profile-header'
import { ProfileCompletion } from '@/components/profile/profile-completion'
import { ProfileStats } from '@/components/profile/profile-stats'
import { SkillsManager } from '@/components/profile/skills-manager'
import { LearningPreferences } from '@/components/profile/learning-preferences'
import { AchievementsCard } from '@/components/profile/achievements-card'
import { SocialLinksForm } from '@/components/profile/social-links-form'
import { PreferencesForm } from '@/components/profile/preferences-form'
import { AppearanceSection } from '@/components/profile/appearance-section'
import { ResumeUpload } from '@/components/profile/resume-upload'
import { BasicInfoForm } from './_components/basic-info-form'
import {
  updateBasicInfoAction,
  updateLearningAction,
  updatePrivacyAction,
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

const TABS = [
  { key: 'profile',      label: 'Profile' },
  { key: 'skills',       label: 'Skills' },
  { key: 'learning',     label: 'Learning' },
  { key: 'achievements', label: 'Achievements' },
  { key: 'preferences',  label: 'Preferences' },
] as const

type TabKey = typeof TABS[number]['key']

export default async function SettingsProfilePage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>
}) {
  const profile = await fetchMyProfile()
  if (!profile) redirect(ROUTES.LOGIN)

  const { tab: rawTab } = await searchParams
  const activeTab: TabKey =
    TABS.find((t) => t.key === rawTab)?.key ?? 'profile'

  const breakdown = {
    avatar: profile.avatar_url !== null,
    bio: Boolean(profile.bio),
    skills: profile.skills.length >= 3,
    learningGoal: profile.learning_goal !== null,
    domains: profile.topics_interest.length >= 1,
    socialLinks: Boolean(
      profile.social_links?.linkedin ||
      profile.social_links?.github ||
      profile.social_links?.portfolio
    ),
  }

  return (
    <div className="space-y-6">
      <ProfileHeader profile={profile} />

      {/* Tab bar */}
      <div
        aria-label="Profile settings sections"
        className="flex overflow-x-auto gap-0 border-b border-border -mb-px"
        role="tablist"
      >
        {TABS.map((tab) => {
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

      {/* Two-column layout on lg+ */}
      <div className="flex flex-col gap-6 lg:flex-row lg:items-start">
        {/* Main tab content */}
        <div className="flex-1 min-w-0 space-y-6">
          {activeTab === 'profile' && (
            <>
              <BasicInfoForm
                profile={profile}
                updateAction={updateBasicInfoAction}
                uploadAction={uploadAvatarAction}
              />
              <SocialLinksForm
                socialLinks={profile.social_links}
                updateAction={updateSocialLinksAction}
              />
              <ResumeUpload
                parseAction={parseResumeAction}
                applyAction={applyResumeAction}
              />
            </>
          )}

          {activeTab === 'skills' && (
            <SkillsManager
              addAction={addSkillAction}
              removeAction={removeSkillAction}
              skills={profile.skills}
            />
          )}

          {activeTab === 'learning' && (
            <>
              <LearningPreferences
                profile={profile}
                updateAction={updateLearningAction}
              />
              <PrivacySection profile={profile} />
            </>
          )}

          {activeTab === 'achievements' && (
            <>
              <AchievementsCard stats={profile.stats} />
              <ProfileStats stats={profile.stats} />
            </>
          )}

          {activeTab === 'preferences' && (
            <>
              <PreferencesForm
                profile={profile}
                updateAction={updatePreferencesAction}
              />
              <AppearanceSection />
            </>
          )}
        </div>

        {/* Sidebar: completion score */}
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

function PrivacySection({ profile }: { profile: Profile }) {
  const TOGGLES: { name: string; label: string; description: string; checked: boolean }[] = [
    {
      name: 'public_enabled',
      label: 'Public profile',
      description: 'Allow anyone to view your profile at your public URL.',
      checked: profile.public_enabled,
    },
    {
      name: 'show_skills',
      label: 'Show skills',
      description: 'Display your skills on your public profile.',
      checked: profile.show_skills,
    },
    {
      name: 'show_achievements',
      label: 'Show achievements',
      description: 'Display your badges and achievements publicly.',
      checked: profile.show_achievements,
    },
    {
      name: 'show_certificates',
      label: 'Show certificates',
      description: 'Display your earned certificates publicly.',
      checked: profile.show_certificates,
    },
    {
      name: 'show_activity',
      label: 'Show activity',
      description: 'Display your learning activity publicly.',
      checked: profile.show_activity,
    },
  ]

  return (
    <section aria-labelledby="privacy-heading" className="card-base p-6 space-y-5">
      <h2 className="text-lg font-semibold text-foreground" id="privacy-heading">
        Privacy
      </h2>

      <form action={updatePrivacyAction} className="space-y-4">
        {TOGGLES.map(({ name, label, description, checked }) => (
          <label
            className="flex items-start justify-between gap-4 cursor-pointer"
            htmlFor={name}
            key={name}
          >
            <div className="space-y-0.5">
              <p className="text-sm font-medium text-foreground">{label}</p>
              <p className="text-xs text-muted-foreground">{description}</p>
            </div>
            {/* Native checkbox styled as a toggle track */}
            <input
              className="sr-only peer"
              defaultChecked={checked}
              id={name}
              name={name}
              type="checkbox"
              value="on"
            />
            <span
              aria-hidden="true"
              className="flex-shrink-0 mt-0.5 h-5 w-9 rounded-full border border-border bg-muted transition-colors duration-[--duration-fast] peer-checked:bg-primary peer-focus-visible:ring-2 peer-focus-visible:ring-primary"
            />
          </label>
        ))}

        <div className="flex justify-end pt-2">
          <Button className="px-5 py-2.5" type="submit">
            Save privacy
          </Button>
        </div>
      </form>
    </section>
  )
}
