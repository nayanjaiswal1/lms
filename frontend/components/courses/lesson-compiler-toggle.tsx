"use client"

import { useState } from "react"
import { Code2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { LabFixedConsole } from "@/components/labs/lab-fixed-console"
import { LessonCodeRunner } from "@/components/courses/lesson-code-runner"
import { RUNNABLE_LANGUAGES } from "@/lib/courses/runnable-languages"
import { useIsOrgFeatureEnabled } from "@/lib/feature-context"
import { FEATURES } from "@/lib/features"

interface LessonCompilerToggleProps {
  language: string
}

// Right-rail entry point for a blank scratch compiler in this lesson's
// language — separate from the inline runners already sitting on each code
// block, for practicing without scrolling back to find one.
export function LessonCompilerToggle({ language }: LessonCompilerToggleProps) {
  const [open, setOpen] = useState(false)
  const label = RUNNABLE_LANGUAGES[language] ?? language
  // Bottom-dock is a code-level toggle (FEATURES.LESSON_COMPILER_BOTTOM_DOCK,
  // see backend/internal/features/service.go's alwaysOrgEnabled) rather than
  // a live admin switch — org-disabled restricts this panel to right-dock only.
  const bottomDockAllowed = useIsOrgFeatureEnabled(FEATURES.LESSON_COMPILER_BOTTOM_DOCK)

  return (
    <>
      <Button className="w-full" size="sm" variant="outline" onClick={() => setOpen((o) => !o)}>
        <Code2 aria-hidden className="h-3.5 w-3.5" />
        {open ? "Close compiler" : `Open ${label} compiler`}
      </Button>
      {open && (
        <LabFixedConsole
          positions={bottomDockAllowed ? ["right", "bottom"] : ["right"]}
          title={`${label} compiler`}
          onClose={() => setOpen(false)}
        >
          <div className="flex h-full flex-col">
            <LessonCodeRunner fill initialCode="" language={language} />
          </div>
        </LabFixedConsole>
      )}
    </>
  )
}
