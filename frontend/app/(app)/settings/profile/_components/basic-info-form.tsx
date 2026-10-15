import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { SettingsSection } from '@/components/profile/settings-section'
import { FormSaveFooter } from '@/components/profile/form-save-footer'
import type { Profile } from '@/lib/profile/types'

interface Props {
  profile: Profile
  updateAction: (formData: FormData) => Promise<void>
}

export function BasicInfoForm({ profile, updateAction }: Props) {
  return (
    <SettingsSection
      description="How you appear to other learners, mentors and instructors."
      id="basic-info"
      title="Basic information"
    >
      <form action={updateAction} className="form-stack">
        <div className="form-row">
          <div className="space-y-1.5">
            <Label htmlFor="name">Full name</Label>
            <Input
              required
              autoComplete="name"
              defaultValue={profile.name}
              id="name"
              name="name"
              placeholder="Your full name"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="display_name">Display name</Label>
            <Input
              aria-describedby="display_name-hint"
              autoComplete="nickname"
              defaultValue={profile.display_name ?? ''}
              id="display_name"
              name="display_name"
              placeholder="@handle"
            />
            <p className="text-xs text-muted-foreground" id="display_name-hint">
              Appears as your @handle on your public profile.
            </p>
          </div>
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="bio">Bio</Label>
          <Textarea
            aria-describedby="bio-hint"
            defaultValue={profile.bio ?? ''}
            id="bio"
            name="bio"
            placeholder="Tell learners a bit about yourself…"
            rows={4}
          />
          <p className="text-xs text-muted-foreground" id="bio-hint">
            A sentence or two about what you do and what you&apos;re learning.
          </p>
        </div>

        <div className="form-row">
          <div className="space-y-1.5">
            <Label htmlFor="current_role">Current role</Label>
            <Input
              autoComplete="organization-title"
              defaultValue={profile.current_role ?? ''}
              id="current_role"
              name="current_role"
              placeholder="e.g. Software Engineer"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="years_of_experience">Years of experience</Label>
            <Input
              defaultValue={profile.years_of_experience ?? ''}
              id="years_of_experience"
              inputMode="numeric"
              max={60}
              min={0}
              name="years_of_experience"
              placeholder="0"
              type="number"
            />
          </div>
        </div>

        <FormSaveFooter label="Save changes" />
      </form>
    </SettingsSection>
  )
}
