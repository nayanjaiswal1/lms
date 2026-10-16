import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { SettingsSection } from "@/components/profile/settings-section"
import { FormSaveFooter } from "@/components/profile/form-save-footer"
import {
  EXPERIENCE_LEVEL_OPTIONS,
  LEARNING_GOAL_OPTIONS,
  LEARNING_STYLE_OPTIONS,
  LEARNING_DOMAIN_OPTIONS,
} from "@/lib/constants"
import type { Profile } from "@/lib/profile/types"

interface Props {
  profile: Pick<
    Profile,
    | "experience_level"
    | "learning_goal"
    | "topics_interest"
    | "preferred_learning_style"
    | "weekly_time_commitment"
  >
  updateAction: (formData: FormData) => Promise<void>
}

// Selectable tile: the whole row is the label, checked state lights the border.
const TILE =
  "flex min-h-11 cursor-pointer items-center gap-3 rounded-md border border-border p-4 text-sm font-medium transition-colors duration-fast ease-smooth hover:bg-muted has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-primary/5"

const LEGEND = "text-sm font-medium text-foreground"
const HINT = "text-xs text-muted-foreground"

export function LearningPreferences({ profile, updateAction }: Props) {
  return (
    <SettingsSection
      description="Used to tailor course recommendations and your AI roadmap."
      id="learning-preferences"
      title="Learning preferences"
    >
      <form action={updateAction} className="flex flex-col gap-8">
        <fieldset className="space-y-3">
          <legend className={LEGEND}>Experience level</legend>
          <RadioGroup
            className="grid grid-cols-1 gap-2 sm:grid-cols-3"
            defaultValue={profile.experience_level ?? undefined}
            name="experience_level"
          >
            {EXPERIENCE_LEVEL_OPTIONS.map((opt) => (
              <Label className={TILE} htmlFor={`exp-${opt.value}`} key={opt.value}>
                <RadioGroupItem id={`exp-${opt.value}`} value={opt.value} />
                {opt.label}
              </Label>
            ))}
          </RadioGroup>
        </fieldset>

        <div className="space-y-1.5">
          <Label htmlFor="learning-goal-select">Learning goal</Label>
          <Select
            defaultValue={profile.learning_goal ?? undefined}
            name="learning_goal"
          >
            <SelectTrigger aria-describedby="learning-goal-hint" className="w-full sm:w-72" id="learning-goal-select">
              <SelectValue placeholder="Select your goal" />
            </SelectTrigger>
            <SelectContent>
              {LEARNING_GOAL_OPTIONS.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <p className={HINT} id="learning-goal-hint">What you&apos;re working towards right now.</p>
        </div>

        <fieldset className="space-y-3">
          <legend className={LEGEND}>Learning domains</legend>
          <p className={HINT}>Pick every area you want to see content for.</p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 md:grid-cols-3">
            {LEARNING_DOMAIN_OPTIONS.map((domain) => (
              <Label className={TILE} htmlFor={`domain-${domain.value}`} key={domain.value}>
                <Checkbox
                  defaultChecked={profile.topics_interest.includes(domain.value)}
                  id={`domain-${domain.value}`}
                  name="topics_interest[]"
                  value={domain.value}
                />
                <span className="min-w-0">{domain.label}</span>
              </Label>
            ))}
          </div>
        </fieldset>

        <fieldset className="space-y-3">
          <legend className={LEGEND}>Preferred learning style</legend>
          <RadioGroup
            className="grid grid-cols-1 gap-2 sm:grid-cols-2"
            defaultValue={profile.preferred_learning_style ?? undefined}
            name="preferred_learning_style"
          >
            {LEARNING_STYLE_OPTIONS.map((opt) => (
              <Label className={TILE} htmlFor={`style-${opt.value}`} key={opt.value}>
                <RadioGroupItem id={`style-${opt.value}`} value={opt.value} />
                {opt.label}
              </Label>
            ))}
          </RadioGroup>
        </fieldset>

        <FormSaveFooter label="Save learning preferences" />
      </form>
    </SettingsSection>
  )
}
