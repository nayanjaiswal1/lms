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
import { SettingsSection } from "@/components/profile/settings-section"
import { FormSaveFooter } from "@/components/profile/form-save-footer"
import { FEATURES } from "@/lib/features"
import { DEFAULT_LANDING_PAGE_OPTIONS, NOTIFICATION_LABELS } from "@/lib/constants"
import type { Profile } from "@/lib/profile/types"

interface Props {
  profile: Pick<
    Profile,
    "language" | "timezone" | "notifications" | "weekly_goal_hrs" | "default_landing_page"
  >
  updateAction: (formData: FormData) => Promise<void>
}

interface ToggleRowProps {
  id: string
  name: string
  label: string
  defaultChecked: boolean
}

const GROUP_TITLE = "text-sm font-semibold text-foreground"

function ToggleRow({ id, name, label, defaultChecked }: ToggleRowProps) {
  return (
    <Label
      className="flex min-h-11 cursor-pointer items-center gap-3 rounded-md px-3 py-2 font-normal transition-colors duration-fast ease-smooth hover:bg-muted"
      htmlFor={id}
    >
      <Checkbox defaultChecked={defaultChecked} id={id} name={name} value="true" />
      {label}
    </Label>
  )
}

export function PreferencesForm({ profile, updateAction }: Props) {
  return (
    <SettingsSection
      description="Region, weekly target, where the logo takes you, and what we email you about."
      id="preferences"
      title="General preferences"
    >
      <form action={updateAction} className="flex flex-col gap-8">
        <fieldset className="space-y-4">
          <legend className={GROUP_TITLE}>Region</legend>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="timezone-input">Timezone</Label>
              <Input
                aria-describedby="timezone-hint"
                defaultValue={profile.timezone ?? ""}
                id="timezone-input"
                name="timezone"
                placeholder="Asia/Kolkata"
                type="text"
              />
              <p className="text-xs text-muted-foreground" id="timezone-hint">
                IANA name, e.g. Europe/London
              </p>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="language-input">Language</Label>
              <Input
                aria-describedby="language-hint"
                defaultValue={profile.language ?? ""}
                id="language-input"
                name="language"
                placeholder="en"
                type="text"
              />
              <p className="text-xs text-muted-foreground" id="language-hint">
                Language tag, e.g. en, fr, de
              </p>
            </div>
          </div>
        </fieldset>

        <fieldset className="space-y-4">
          <legend className={GROUP_TITLE}>Goals &amp; navigation</legend>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="weekly-goal-input">Weekly learning goal</Label>
              <Input
                aria-describedby="weekly-goal-hint"
                defaultValue={profile.weekly_goal_hrs ?? ""}
                id="weekly-goal-input"
                inputMode="numeric"
                max={168}
                min={1}
                name="weekly_goal_hrs"
                placeholder="5"
                step={1}
                type="number"
              />
              <p className="text-xs text-muted-foreground" id="weekly-goal-hint">
                Hours per week, 1–168.
              </p>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="default-landing-page-select">Logo takes you to</Label>
              <Select
                defaultValue={profile.default_landing_page ?? undefined}
                name="default_landing_page"
              >
                <SelectTrigger className="w-full" id="default-landing-page-select">
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
          </div>
        </fieldset>

        <fieldset className="space-y-2">
          <legend className={GROUP_TITLE}>Notifications</legend>
          <div className="-mx-3 grid gap-1 sm:grid-cols-2">
            <ToggleRow
              defaultChecked={profile.notifications?.email === true}
              id="email-notifications"
              label="Email notifications"
              name="email_notifications"
            />
            <ToggleRow
              defaultChecked={profile.notifications?.push === true}
              id="push-notifications"
              label="Push notifications"
              name="push_notifications"
            />
            <ToggleRow
              defaultChecked={profile.notifications?.weekly_recap !== false}
              id="weekly-recap"
              label={NOTIFICATION_LABELS.weeklyRecap}
              name="weekly_recap"
            />
            {/* Beta feature — only entitled students ever see this toggle
                (mode="hide": AccessGate renders nothing for anyone else). */}
            <AccessGate feature={FEATURES.REVISION_DIGEST} mode="hide">
              <ToggleRow
                defaultChecked={profile.notifications?.revision_digest !== false}
                id="revision-digest"
                label="Nightly revision digest email"
                name="revision_digest"
              />
            </AccessGate>
          </div>
        </fieldset>

        <FormSaveFooter label="Save preferences" />
      </form>
    </SettingsSection>
  )
}
