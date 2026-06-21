import { ProfileAvatar } from '@/components/profile/profile-avatar'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Button } from '@/components/ui/button'
import type { Profile } from '@/lib/profile/types'

interface Props {
  profile: Profile
  updateAction: (formData: FormData) => Promise<void>
  uploadAction: (formData: FormData) => Promise<void>
}

export function BasicInfoForm({ profile, updateAction, uploadAction }: Props) {
  return (
    <section aria-labelledby="basic-info-heading" className="card-base p-6 space-y-6">
      <h2 className="text-lg font-semibold text-foreground" id="basic-info-heading">
        Basic Information
      </h2>

      <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-center">
        <ProfileAvatar
          avatarUrl={profile.avatar_url}
          editable={true}
          name={profile.name}
          size="lg"
          uploadAction={uploadAction}
        />
        <div>
          <p className="text-sm font-medium text-foreground">Profile photo</p>
          <p className="text-xs text-muted-foreground mt-0.5">
            JPG, PNG or GIF. Max 5 MB.
          </p>
        </div>
      </div>

      <form action={updateAction} className="form-stack">
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="name">Full name</Label>
            <Input
              required
              defaultValue={profile.name}
              id="name"
              name="name"
              placeholder="Your full name"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="display_name">Display name</Label>
            <Input
              defaultValue={profile.display_name ?? ''}
              id="display_name"
              name="display_name"
              placeholder="@handle"
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="bio">Bio</Label>
          <Textarea
            defaultValue={profile.bio ?? ''}
            id="bio"
            name="bio"
            placeholder="Tell learners a bit about yourself…"
            rows={3}
          />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="current_role">Current role</Label>
            <Input
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
              max={60}
              min={0}
              name="years_of_experience"
              placeholder="0"
              type="number"
            />
          </div>
        </div>

        <div className="flex justify-end pt-2">
          <Button className="px-5 py-2.5" type="submit">
            Save changes
          </Button>
        </div>
      </form>
    </section>
  )
}
