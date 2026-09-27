import type { Profile } from '@/lib/profile/types'
import { Button } from '@/components/ui/button'
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
            Save visibility
          </Button>
        </div>
      </form>
    </section>
  )
}
