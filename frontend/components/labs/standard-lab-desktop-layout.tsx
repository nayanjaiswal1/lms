"use client"

import type { ReactNode } from "react"
import { SessionExpiredOverlay } from "@/components/labs/session-expired-overlay"
import { cn } from "@/lib/utils"
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle,
} from "@/components/ui/resizable"
import { LabTaskPanel } from "@/components/labs/lab-task-panel"
import { LabTaskChecklist } from "@/components/labs/lab-task-checklist"
import { LabConsoleWorkspace } from "@/components/labs/lab-console-workspace"
import { LabFixedConsole } from "@/components/labs/lab-fixed-console"
import type { Lab, TaskCompletion } from "@/lib/labs"

interface StandardLabDesktopLayoutProps {
  lab: Lab
  orientation: "horizontal" | "vertical"
  consoleMode: "boxed" | "fixed"
  hideTaskChecklist: boolean
  isCodeLab: boolean
  isAuthExpired: boolean
  isVerifying: boolean
  completions: TaskCompletion[]
  hintsUsedByTask: Record<string, number>
  maxHints: number
  maxScore: number
  score: number
  selectedTaskId: string | null
  workspacePanel: ReactNode
  onCheck: (taskId: string) => void
  onHint: (taskId: string) => void
  onLogin: () => void
  onTaskSelect: (taskId: string) => void
}

/** md+ arrangement of the standard lab workspace: split panels, boxed console or fixed console. */
export function StandardLabDesktopLayout({
  lab,
  orientation,
  consoleMode,
  hideTaskChecklist,
  isCodeLab,
  isAuthExpired,
  isVerifying,
  completions,
  hintsUsedByTask,
  maxHints,
  maxScore,
  score,
  selectedTaskId,
  workspacePanel,
  onCheck,
  onHint,
  onLogin,
  onTaskSelect,
}: StandardLabDesktopLayoutProps) {
  return (
  <div
    className={cn(
      "relative hidden md:flex flex-1",
      !(lab.layout === "console" && consoleMode === "fixed") && "overflow-hidden",
    )}
  >
    {isAuthExpired && <SessionExpiredOverlay onLogin={onLogin} />}
    {lab.layout === "console" ? (
      consoleMode === "fixed" ? (
        <div className="flex w-full flex-col gap-4">
          {!hideTaskChecklist && (
            <LabTaskChecklist
              completions={completions}
              hintsUsedByTask={hintsUsedByTask}
              isVerifying={isVerifying}
              maxHints={maxHints}
              maxScore={maxScore}
              score={score}
              scrollable={false}
              selectedTaskId={selectedTaskId}
              tasks={lab.tasks}
              onCheck={onCheck}
              onHint={onHint}
              onTaskSelect={onTaskSelect}
            />
          )}
          <LabFixedConsole title={isCodeLab ? "Editor" : "Console"}>
            {workspacePanel}
          </LabFixedConsole>
        </div>
      ) : (
        <LabConsoleWorkspace
          completions={completions}
          hintsUsedByTask={hintsUsedByTask}
          isVerifying={isVerifying}
          maxHints={maxHints}
          maxScore={maxScore}
          score={score}
          selectedTaskId={selectedTaskId}
          tasks={lab.tasks}
          workspacePanel={workspacePanel}
          onCheck={onCheck}
          onHint={onHint}
          onTaskSelect={onTaskSelect}
        />
      )
    ) : (
      <ResizablePanelGroup orientation={orientation}>
        <ResizablePanel
          className={
            orientation === "horizontal"
              ? "border-r border-border"
              : "border-b border-border"
          }
          defaultSize="24%"
          id="lab-tasks"
          maxSize="45%"
          minSize="18%"
        >
          <LabTaskPanel
            completions={completions}
            hintsUsedByTask={hintsUsedByTask}
            maxHints={maxHints}
            maxScore={maxScore}
            score={score}
            selectedTaskId={selectedTaskId}
            tasks={lab.tasks}
            onHint={onHint}
            onTaskSelect={onTaskSelect}
          />
        </ResizablePanel>
        <ResizableHandle withHandle orientation={orientation} />
        <ResizablePanel defaultSize="76%" id="lab-workspace" minSize="40%">
          {workspacePanel}
        </ResizablePanel>
      </ResizablePanelGroup>
    )}
  </div>
  )
}
