import { Button } from "@/components/ui/button"
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

export function LearningPreferences({ profile, updateAction }: Props) {
  return (
    <section aria-label="Learning preferences" className="card-base p-6">
      <h2 className="section-title text-lg mb-6">Learning Preferences</h2>

      <form action={updateAction} className="form-stack">
        {/* Experience Level */}
        <fieldset className="space-y-3">
          <legend className="text-sm font-medium text-foreground">
            Experience Level
          </legend>
          <RadioGroup
            className="flex flex-wrap gap-4"
            defaultValue={profile.experience_level ?? undefined}
            name="experience_level"
          >
            {EXPERIENCE_LEVEL_OPTIONS.map((opt) => (
              <div className="flex items-center gap-2" key={opt.value}>
                <RadioGroupItem
                  id={`exp-${opt.value}`}
                  value={opt.value}
                />
                <Label className="cursor-pointer" htmlFor={`exp-${opt.value}`}>
                  {opt.label}
                </Label>
              </div>
            ))}
          </RadioGroup>
        </fieldset>

        {/* Learning Domains */}
        <fieldset className="space-y-3">
          <legend className="text-sm font-medium text-foreground">
            Learning Domains
          </legend>
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
            {LEARNING_DOMAIN_OPTIONS.map((domain) => (
              <div className="flex items-center gap-2" key={domain.value}>
                <Checkbox
                  defaultChecked={profile.topics_interest.includes(domain.value)}
                  id={`domain-${domain.value}`}
                  name="topics_interest[]"
                  value={domain.value}
                />
                <Label
                  className="cursor-pointer text-sm"
                  htmlFor={`domain-${domain.value}`}
                >
                  {domain.label}
                </Label>
              </div>
            ))}
          </div>
        </fieldset>

        {/* Learning Goal */}
        <div className="space-y-2">
          <Label htmlFor="learning-goal-select">Learning Goal</Label>
          <Select
            defaultValue={profile.learning_goal ?? undefined}
            name="learning_goal"
          >
            <SelectTrigger className="w-full sm:w-72" id="learning-goal-select">
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
        </div>

        {/* Preferred Style */}
        <fieldset className="space-y-3">
          <legend className="text-sm font-medium text-foreground">
            Preferred Learning Style
          </legend>
          <RadioGroup
            className="flex flex-wrap gap-4"
            defaultValue={profile.preferred_learning_style ?? undefined}
            name="preferred_learning_style"
          >
            {LEARNING_STYLE_OPTIONS.map((opt) => (
              <div className="flex items-center gap-2" key={opt.value}>
                <RadioGroupItem
                  id={`style-${opt.value}`}
                  value={opt.value}
                />
                <Label className="cursor-pointer" htmlFor={`style-${opt.value}`}>
                  {opt.label}
                </Label>
              </div>
            ))}
          </RadioGroup>
        </fieldset>

        <div className="pt-2">
          <Button className="px-5 py-2.5" type="submit">
            Save Learning Preferences
          </Button>
        </div>
      </form>
    </section>
  )
}
