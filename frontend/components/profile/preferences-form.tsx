import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { AccessGate } from "@/components/shared/access-gate"
import { FEATURES } from "@/lib/features"
import { DEFAULT_LANDING_PAGE_OPTIONS } from "@/lib/constants"
import type { Profile } from "@/lib/profile/types"

interface Props {
  profile: Pick<
    Profile,
    "language" | "timezone" | "notifications" | "weekly_goal_hrs" | "default_landing_page"
  >
  updateAction: (formData: FormData) => Promise<void>
}

export function PreferencesForm({ profile, updateAction }: Props) {
  return (
    <section aria-label="Preferences" className="card-base p-6">
      <h2 className="section-title mb-6">Preferences</h2>

      <form action={updateAction} className="form-stack">
        {/* Timezone */}
        <div className="space-y-1.5">
          <Label htmlFor="timezone-input">Timezone</Label>
          <Input
            className="px-3 py-2.5"
            defaultValue={profile.timezone ?? ""}
            id="timezone-input"
            name="timezone"
            placeholder="America/New_York"
            type="text"
          />
          <p className="text-xs text-muted-foreground">
            IANA timezone identifier, e.g. Europe/London
          </p>
        </div>

        {/* Language */}
        <div className="space-y-1.5">
          <Label htmlFor="language-input">Language</Label>
          <Input
            className="px-3 py-2.5"
            defaultValue={profile.language ?? ""}
            id="language-input"
            name="language"
            placeholder="en"
            type="text"
          />
          <p className="text-xs text-muted-foreground">
            BCP-47 language tag, e.g. en, fr, de
          </p>
        </div>

        {/* Weekly Goal */}
        <div className="space-y-1.5">
          <Label htmlFor="weekly-goal-input">Weekly Learning Goal (hours)</Label>
          <Input
            className="px-3 py-2.5 w-full sm:w-36"
            defaultValue={profile.weekly_goal_hrs ?? ""}
            id="weekly-goal-input"
            max={168}
            min={1}
            name="weekly_goal_hrs"
            placeholder="5"
            step={1}
            type="number"
          />
        </div>

        {/* Sidebar logo destination */}
        <div className="space-y-2">
          <Label htmlFor="default-landing-page-select">Logo takes you to</Label>
          <Select
            defaultValue={profile.default_landing_page ?? undefined}
            name="default_landing_page"
          >
            <SelectTrigger className="w-full sm:w-72" id="default-landing-page-select">
              <SelectValue placeholder="Dashboard (default)" />
            </SelectTrigger>
            <SelectContent>
              {DEFAULT_LANDING_PAGE_OPTIONS.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {/* Notifications */}
        <fieldset className="space-y-3">
          <legend className="text-sm font-medium text-foreground">
            Notifications
          </legend>

          <div className="flex items-center gap-2">
            <Checkbox
              defaultChecked={profile.notifications?.email === true}
              id="email-notifications"
              name="email_notifications"
              value="true"
            />
            <Label className="cursor-pointer" htmlFor="email-notifications">
              Email notifications
            </Label>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              defaultChecked={profile.notifications?.push === true}
              id="push-notifications"
              name="push_notifications"
              value="true"
            />
            <Label className="cursor-pointer" htmlFor="push-notifications">
              Push notifications
            </Label>
          </div>

          {/* Beta feature — only entitled students ever see this toggle
              (mode="hide": AccessGate renders nothing for anyone else). */}
          <AccessGate feature={FEATURES.REVISION_DIGEST} mode="hide">
            <div className="flex items-center gap-2">
              <Checkbox
                defaultChecked={profile.notifications?.revision_digest !== false}
                id="revision-digest"
                name="revision_digest"
                value="true"
              />
              <Label className="cursor-pointer" htmlFor="revision-digest">
                Nightly revision digest email
              </Label>
            </div>
          </AccessGate>
        </fieldset>

        <div className="pt-2">
          <Button className="px-5 py-2.5" type="submit">
            Save Preferences
          </Button>
        </div>
      </form>
    </section>
  )
}
