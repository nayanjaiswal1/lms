import type { Profile } from '@/lib/profile/types'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { updatePrivacyAction } from '@/app/(app)/settings/profile/actions'
// Public-profile visibility toggles. Lives on Settings → Privacy alongside
// data export and account deletion.
export function ProfileVisibilityForm({ profile }: { profile: Profile }) {
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
    <section aria-labelledby="visibility-heading" className="card-base p-6 space-y-5">
      <h2 className="text-lg font-semibold text-foreground" id="visibility-heading">
        Profile visibility
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
            <Switch
              className="mt-0.5 h-5 w-9 border-border data-[state=checked]:border-primary focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
              defaultChecked={checked}
              id={name}
              name={name}
              thumbClassName="h-4 w-4 shadow-card data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0.5"
              value="on"
            />
          </label>
        ))}

        <div className="flex justify-end pt-2">
          <Button className="px-5 py-2.5" type="submit">
            Save visibility
          </Button>
        </div>
      </form>
    </section>
  )
}
