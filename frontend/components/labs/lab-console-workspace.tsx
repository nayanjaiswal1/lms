"use client"

import { useState, type ReactNode } from "react"
import { ChevronDown, ChevronUp, Maximize2, Minimize2, TerminalSquare } from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { LabTaskChecklist } from "@/components/labs/lab-task-checklist"
import type { LabTask, TaskCompletion } from "@/lib/labs"

type DrawerState = "closed" | "open" | "expanded"

const DRAWER_HEIGHT: Record<DrawerState, string> = {
  closed: "h-11",
  open: "h-72",
  expanded: "h-[70dvh]",
}

interface LabConsoleWorkspaceProps {
  tasks: LabTask[]
  completions: TaskCompletion[]
  score: number
  maxScore: number
  selectedTaskId: string | null
  isVerifying: boolean
  onTaskSelect: (taskId: string) => void
  onCheck: (taskId: string) => void
  workspacePanel: ReactNode
}

// Google Cloud Skills Boost style layout: every task is visible at once in a
// scrollable checklist with its own "Check my progress" action, and the
// terminal/editor lives in a bottom drawer the student can collapse, open, or
// expand — instead of the split layout's side-by-side task list + workspace.
export function LabConsoleWorkspace({
  tasks,
  completions,
  score,
  maxScore,
  selectedTaskId,
  isVerifying,
  onTaskSelect,
  onCheck,
  workspacePanel,
}: LabConsoleWorkspaceProps) {
  const [drawerState, setDrawerState] = useState<DrawerState>("open")

  function toggleDrawer() {
    setDrawerState((s) => (s === "closed" ? "open" : "closed"))
  }

  function toggleExpand() {
    setDrawerState((s) => (s === "expanded" ? "open" : "expanded"))
  }

  return (
    <div className="flex h-full flex-col">
      <LabTaskChecklist
        completions={completions}
        isVerifying={isVerifying}
        maxScore={maxScore}
        score={score}
        selectedTaskId={selectedTaskId}
        tasks={tasks}
        onCheck={onCheck}
        onTaskSelect={onTaskSelect}
      />

      <div
        className={cn(
          "flex flex-col border-t border-border bg-card shrink-0 overflow-hidden transition-[height] duration-normal",
          DRAWER_HEIGHT[drawerState],
        )}
      >
        <div className="flex h-11 shrink-0 items-center gap-2 px-3">
          <TerminalSquare aria-hidden className="h-3.5 w-3.5 text-muted-foreground shrink-0" />
          <span className="text-xs font-medium text-foreground">Console</span>
          <div className="ml-auto flex items-center gap-1">
            {drawerState !== "closed" && (
              <Button
                aria-label={drawerState === "expanded" ? "Collapse console" : "Expand console"}
                className="touch-target"
                size="icon"
                variant="ghost"
                onClick={toggleExpand}
              >
                {drawerState === "expanded" ? (
                  <Minimize2 aria-hidden className="h-3.5 w-3.5" />
                ) : (
                  <Maximize2 aria-hidden className="h-3.5 w-3.5" />
                )}
              </Button>
            )}
            <Button
              aria-label={drawerState === "closed" ? "Open console" : "Close console"}
              className="touch-target"
              size="icon"
              variant="ghost"
              onClick={toggleDrawer}
            >
              {drawerState === "closed" ? (
                <ChevronUp aria-hidden className="h-3.5 w-3.5" />
              ) : (
                <ChevronDown aria-hidden className="h-3.5 w-3.5" />
              )}
            </Button>
          </div>
        </div>

        <div
          className={cn(
            "flex-1 min-h-0",
            drawerState === "closed" && "invisible pointer-events-none",
          )}
        >
          {workspacePanel}
        </div>
      </div>
    </div>
  )
}
