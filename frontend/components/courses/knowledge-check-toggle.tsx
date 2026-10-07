"use client"

import { Checkbox } from "@/components/ui/checkbox"
import { Label } from "@/components/ui/label"
import { setHideKnowledgeChecks, useHideKnowledgeChecks } from "@/lib/courses/knowledge-check-settings"

export function KnowledgeCheckToggle() {
  const hidden = useHideKnowledgeChecks()
  return (
    <div className="flex items-start gap-3 rounded-lg border border-border p-4">
      <Checkbox
        checked={hidden}
        className="mt-0.5"
        id="hide-knowledge-checks"
        onCheckedChange={(v) => setHideKnowledgeChecks(Boolean(v))}
      />
      <div className="flex flex-col gap-0.5">
        <Label className="cursor-pointer" htmlFor="hide-knowledge-checks">
          Hide knowledge checks in all courses
        </Label>
        <p className="text-xs text-muted-foreground">
          Lessons no longer show the Knowledge Check, and you can mark them complete without answering. Saved on this device.
        </p>
      </div>
    </div>
  )
}
