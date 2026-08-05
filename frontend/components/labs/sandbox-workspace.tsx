"use client"

import { useReducer } from "react"
import { Loader2, MonitorOff, Play, Send } from "lucide-react"
import { Button } from "@/components/ui/button"
import { IconMessage } from "@/components/shared/icon-message"
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle,
} from "@/components/ui/resizable"
import { LabFileTree } from "@/components/labs/lab-file-tree"
import { LabFileEditor } from "@/components/labs/lab-file-editor"
import { LabQuickOpen } from "@/components/labs/lab-quick-open"
import { LabPreviewPane } from "@/components/labs/lab-preview-pane"
import { SandboxTerminalPanel, MAX_SANDBOX_TERMINALS } from "@/components/labs/sandbox-terminal-panel"
import { SandboxTestsPanel } from "@/components/labs/sandbox-tests-panel"
import { useLabFiles } from "@/hooks/use-lab-files"
import { useLabPorts } from "@/hooks/use-lab-ports"
import { useLabRunSubmit } from "@/hooks/use-lab-run-submit"
import type { Lab } from "@/lib/labs"

interface SandboxUIState {
  /** 0 = follow the first detected port. */
  selectedPort: number
  panelTab: number | "tests"
  terminalIds: number[]
  nextTerminalId: number
}

type SandboxUIAction =
  | { type: "selectPort"; port: number }
  | { type: "selectTab"; tab: number | "tests" }
  | { type: "addTerminal" }
  | { type: "closeTerminal"; id: number }
  | { type: "showTests" }

function sandboxUIReducer(state: SandboxUIState, action: SandboxUIAction): SandboxUIState {
  switch (action.type) {
    case "selectPort":
      return { ...state, selectedPort: action.port }
    case "selectTab":
      return { ...state, panelTab: action.tab }
    case "addTerminal": {
      if (state.terminalIds.length >= MAX_SANDBOX_TERMINALS) return state
      const id = state.nextTerminalId
      return { ...state, terminalIds: [...state.terminalIds, id], panelTab: id, nextTerminalId: id + 1 }
    }
    case "closeTerminal": {
      const terminalIds = state.terminalIds.filter((id) => id !== action.id)
      if (terminalIds.length === 0) return state
      const panelTab = state.panelTab === action.id ? terminalIds[terminalIds.length - 1] : state.panelTab
      return { ...state, terminalIds, panelTab }
    }
    case "showTests":
      return { ...state, panelTab: "tests" }
  }
}

interface SandboxWorkspaceProps {
  sessionId: string
  lab: Lab
  onScoreChange?: (score: number) => void
}

/**
 * CodeSandbox-style IDE for sandbox/playground labs: file tree + editor +
 * auto-detected multi-port preview on top, VS Code-style multi-terminal panel
 * below, with HackerEarth-style Run (visible sample tests) and Submit (batch
 * hidden verification) when the lab defines them. Rendered by
 * LabWorkspaceContent in place of the task-checklist layout; hosts provide
 * timer/reset/end chrome around it.
 */
export function SandboxWorkspace({ sessionId, lab, onScoreChange }: SandboxWorkspaceProps) {
  const [ui, dispatch] = useReducer(sandboxUIReducer, {
    selectedPort: 0,
    panelTab: 1,
    terminalIds: [1],
    nextTerminalId: 2,
  })
  const filesState = useLabFiles(sessionId, true)
  const { ports } = useLabPorts(sessionId, true)
  const { run, submit, runResult, submitResult, error, busy } = useLabRunSubmit(
    sessionId,
    (result) => onScoreChange?.(result.score),
  )

  // Follow detection instead of storing it: the chosen port stays active
  // while it exists, otherwise fall back to the first detected port.
  const activePort =
    ui.selectedPort > 0 && ports.some((p) => p.port === ui.selectedPort)
      ? ui.selectedPort
      : (ports[0]?.port ?? 0)

  const showTests = lab.tasks.length > 0 || lab.has_run_script

  return (
    <>
      {/* Mobile: the IDE needs a real screen. */}
      <IconMessage className="bg-muted/50 md:hidden" icon={MonitorOff} variant="strip">
        The sandbox workspace requires a larger screen.
      </IconMessage>

      <div className="hidden md:flex flex-col flex-1 min-h-0">
        <LabQuickOpen files={filesState.files} onOpen={filesState.openFile} />
        {(lab.has_run_script || lab.tasks.length > 0) && (
          <div className="flex items-center justify-end gap-2 border-b border-border bg-card px-3 py-1.5 shrink-0">
            {lab.has_run_script && (
              <Button
                className="gap-1.5"
                disabled={busy !== null}
                size="sm"
                variant="outline"
                onClick={() => {
                  dispatch({ type: "showTests" })
                  run()
                }}
              >
                {busy === "run" ? (
                  <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                ) : (
                  <Play aria-hidden className="h-3.5 w-3.5" />
                )}
                Run
              </Button>
            )}
            {lab.tasks.length > 0 && (
              <Button
                className="gap-1.5"
                disabled={busy !== null}
                size="sm"
                onClick={() => {
                  dispatch({ type: "showTests" })
                  submit()
                }}
              >
                {busy === "submit" ? (
                  <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                ) : (
                  <Send aria-hidden className="h-3.5 w-3.5" />
                )}
                Submit
              </Button>
            )}
          </div>
        )}

        <div className="flex flex-1 min-h-0">
          <aside className="w-56 shrink-0 border-r border-border overflow-hidden">
            <LabFileTree
              files={filesState.files}
              isBusy={filesState.isLoading || filesState.isSaving}
              selectedPath={filesState.activePath ?? undefined}
              onCreate={filesState.createFile}
              onCreateFolder={filesState.createFolder}
              onDelete={filesState.deleteFile}
              onOpen={filesState.openFile}
              onRename={filesState.renameFile}
            />
          </aside>

          <div className="flex-1 min-w-0">
            <ResizablePanelGroup orientation="vertical">
              <ResizablePanel defaultSize="65%" id="sandbox-main" minSize="30%">
                <ResizablePanelGroup orientation="horizontal">
                  <ResizablePanel defaultSize="55%" id="sandbox-editor" minSize="30%">
                    {/* No onValidate: manifest validation is a guided container-lab
                        concern — sandbox labs check their work with Run/Submit. */}
                    <LabFileEditor
                      activePath={filesState.activePath}
                      isSaving={filesState.isSaving}
                      openFiles={filesState.openFiles}
                      validateResult={filesState.validateResult}
                      onChange={filesState.updateContent}
                      onCloseTab={filesState.closeFile}
                      onSave={filesState.save}
                      onSelectTab={filesState.openFile}
                    />
                  </ResizablePanel>
                  <ResizableHandle withHandle orientation="horizontal" />
                  <ResizablePanel defaultSize="45%" id="sandbox-preview" minSize="20%">
                    <LabPreviewPane
                      ports={ports}
                      previewPort={activePort}
                      sessionId={sessionId}
                      onSelectPort={(port) => dispatch({ type: "selectPort", port })}
                    />
                  </ResizablePanel>
                </ResizablePanelGroup>
              </ResizablePanel>
              <ResizableHandle withHandle orientation="vertical" />
              <ResizablePanel defaultSize="35%" id="sandbox-panel" minSize="15%">
                <SandboxTerminalPanel
                  activeTab={ui.panelTab}
                  sessionId={sessionId}
                  showTests={showTests}
                  terminalIds={ui.terminalIds}
                  testsContent={
                    <SandboxTestsPanel
                      error={error}
                      runResult={runResult}
                      submitResult={submitResult}
                      tasks={lab.tasks}
                    />
                  }
                  onAddTerminal={() => dispatch({ type: "addTerminal" })}
                  onCloseTerminal={(id) => dispatch({ type: "closeTerminal", id })}
                  onSelectTab={(tab) => dispatch({ type: "selectTab", tab })}
                />
              </ResizablePanel>
            </ResizablePanelGroup>
          </div>
        </div>
      </div>
    </>
  )
}
