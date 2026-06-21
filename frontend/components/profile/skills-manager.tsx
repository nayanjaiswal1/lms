"use client"

import { useState } from "react"
import { X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
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

function AddSkillButton() {
  return (
    <Button size="default" type="submit">
      Add Skill
    </Button>
  )
}

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
    <section aria-label="Skills manager" className="card-base p-6">
      <h2 className="section-title text-lg mb-4">Skills</h2>

      {!readonly && (
        <form action={handleAdd} className="mb-6">
          <datalist id="skill-suggestions">
            {SUGGESTED_SKILLS.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>

          <div className="flex flex-col gap-3 md:flex-row md:items-end">
            <div className="flex-1 space-y-1">
              <Label htmlFor="skill-name-input">Skill name</Label>
              <Input
                required
                autoComplete="off"
                className="px-3 py-2.5"
                id="skill-name-input"
                list="skill-suggestions"
                name="skill_name"
                placeholder="e.g. TypeScript"
                value={skillName}
                onChange={(e) => setSkillName(e.target.value)}
              />
            </div>

            <div className="space-y-1">
              <Label htmlFor="skill-level-trigger">Level</Label>
              <input name="skill_level" type="hidden" value={skillLevel} />
              <Select
                value={skillLevel}
                onValueChange={(v) => setSkillLevel(v as Skill["skill_level"])}
              >
                <SelectTrigger className="w-full md:w-44" id="skill-level-trigger">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="beginner">Beginner</SelectItem>
                  <SelectItem value="intermediate">Intermediate</SelectItem>
                  <SelectItem value="advanced">Advanced</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <AddSkillButton />
          </div>
        </form>
      )}

      {skills.length === 0 ? (
        <p className="text-sm text-muted-foreground empty-state py-6">
          No skills added yet. Add your first skill above.
        </p>
      ) : (
        <div className="flex flex-wrap gap-2">
          {skills.map((skill) => (
            <div className="flex items-center gap-1" key={skill.id}>
              <Badge className="gap-1.5 pr-1 pl-2.5" variant="secondary">
                <span
                  aria-label={LEVEL_LABELS[skill.skill_level]}
                  className={cn(
                    "w-2 h-2 rounded-full shrink-0",
                    LEVEL_DOT[skill.skill_level]
                  )}
                />
                <span>{skill.skill_name}</span>

                {!readonly && (
                  <form action={() => { void removeAction(skill.id) }} className="contents">
                    <button
                      aria-label={`Remove ${skill.skill_name}`}
                      className={cn(
                        "ml-0.5 rounded-sm p-0.5",
                        "hover:bg-muted transition-colors duration-fast",
                        "touch-target"
                      )}
                      type="submit"
                    >
                      <X size={12} />
                    </button>
                  </form>
                )}
              </Badge>
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
