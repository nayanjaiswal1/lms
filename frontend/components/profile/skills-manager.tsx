"use client"

import { useState } from "react"
import { Plus, Sparkles, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { SettingsSection } from "@/components/profile/settings-section"
import { cn } from "@/lib/utils"
import { SUGGESTED_SKILLS } from "@/lib/constants"
import type { Skill } from "@/lib/profile/types"

interface Props {
  skills: Skill[]
  addAction: (_prev: unknown, formData: FormData) => Promise<{ error?: string }>
  removeAction: (skillId: string) => Promise<{ error?: string }>
  readonly?: boolean
}

const LEVEL_DOT: Record<Skill["skill_level"], string> = {
  beginner:     "bg-muted-foreground",
  intermediate: "bg-primary/60",
  advanced:     "bg-primary",
}

const LEVEL_LABELS: Record<Skill["skill_level"], string> = {
  beginner:     "Beginner",
  intermediate: "Intermediate",
  advanced:     "Advanced",
}

const LEVELS = Object.keys(LEVEL_LABELS) as Skill["skill_level"][]

export function SkillsManager({ skills, addAction, removeAction, readonly = false }: Props) {
  const [skillName,  setSkillName]  = useState("")
  const [skillLevel, setSkillLevel] = useState<Skill["skill_level"]>("beginner")

  async function handleAdd(formData: FormData) {
    const result = await addAction(undefined, formData)
    if (!result.error) {
      setSkillName("")
      setSkillLevel("beginner")
    }
  }

  return (
    <SettingsSection
      action={
        <span className="text-sm text-muted-foreground">
          {skills.length} {skills.length === 1 ? "skill" : "skills"}
        </span>
      }
      description="Add at least three to complete your profile. The dot shows your level."
      id="skills"
      title="Skills"
    >
      {!readonly && (
        <form action={handleAdd} className="mb-6 rounded-lg bg-muted p-4">
          <datalist id="skill-suggestions">
            {SUGGESTED_SKILLS.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>

          <div className="flex flex-col gap-3 md:flex-row md:items-end">
            <div className="min-w-0 flex-1 space-y-1.5">
              <Label htmlFor="skill-name-input">Skill name</Label>
              <Input
                required
                autoComplete="off"
                className="bg-background"
                id="skill-name-input"
                list="skill-suggestions"
                name="skill_name"
                placeholder="e.g. TypeScript"
                value={skillName}
                onChange={(e) => setSkillName(e.target.value)}
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="skill-level-trigger">Level</Label>
              <input name="skill_level" type="hidden" value={skillLevel} />
              <Select
                value={skillLevel}
                onValueChange={(v) => setSkillLevel(v as Skill["skill_level"])}
              >
                <SelectTrigger className="w-full bg-background md:w-44" id="skill-level-trigger">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {LEVELS.map((level) => (
                    <SelectItem key={level} value={level}>
                      {LEVEL_LABELS[level]}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <Button className="w-full md:w-auto" size="lg" type="submit">
              <Plus aria-hidden="true" className="h-4 w-4" />
              Add skill
            </Button>
          </div>
        </form>
      )}

      {skills.length === 0 ? (
        <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-border px-4 py-8 text-center">
          <Sparkles aria-hidden="true" className="h-6 w-6 text-muted-foreground" />
          <p className="text-sm font-medium text-foreground">No skills yet</p>
          <p className="max-w-xs text-sm text-muted-foreground">
            {readonly ? "Nothing listed here yet." : "Start typing above — suggestions appear as you go."}
          </p>
        </div>
      ) : (
        <>
          <ul className="flex flex-wrap gap-2">
            {skills.map((skill) => (
              <li
                className={cn(
                  "inline-flex min-h-11 items-center gap-2 rounded-md border border-border bg-card pl-3 text-sm text-foreground lg:min-h-9",
                  readonly && "pr-3"
                )}
                key={skill.id}
              >
                <span
                  aria-hidden="true"
                  className={cn("h-2 w-2 shrink-0 rounded-full", LEVEL_DOT[skill.skill_level])}
                />
                <span className="min-w-0 break-all">{skill.skill_name}</span>
                <span className="sr-only">({LEVEL_LABELS[skill.skill_level]})</span>

                {!readonly && (
                  <form action={() => { void removeAction(skill.id) }} className="contents">
                    <Button
                      aria-label={`Remove ${skill.skill_name}`}
                      className="touch-target-dense rounded-md text-muted-foreground transition-colors duration-fast hover:bg-muted hover:text-foreground lg:h-9 lg:w-9"
                      type="submit"
                      variant="unstyled"
                    >
                      <X aria-hidden="true" size={14} />
                    </Button>
                  </form>
                )}
              </li>
            ))}
          </ul>

          <ul aria-label="Skill level legend" className="mt-4 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
            {LEVELS.map((level) => (
              <li className="inline-flex items-center gap-1.5" key={level}>
                <span aria-hidden="true" className={cn("h-2 w-2 rounded-full", LEVEL_DOT[level])} />
                {LEVEL_LABELS[level]}
              </li>
            ))}
          </ul>
        </>
      )}
    </SettingsSection>
  )
}
