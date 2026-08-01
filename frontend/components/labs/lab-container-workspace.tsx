"use client"

import { useState } from "react"
import dynamic from "next/dynamic"
import { TerminalSquare, FolderTree, Boxes, AppWindow, Loader2, CheckCircle2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle,
} from "@/components/ui/resizable"
import { LabFileTree } from "@/components/labs/lab-file-tree"
import { LabFileEditor } from "@/components/labs/lab-file-editor"
import { LabQuickOpen } from "@/components/labs/lab-quick-open"
import { LabPreviewPane } from "@/components/labs/lab-preview-pane"
import { LabResourcesPanel } from "@/components/labs/lab-resources-panel"
import { useLabFiles } from "@/hooks/use-lab-files"
import { useLabResources } from "@/hooks/use-lab-resources"
import { useLabTerminal } from "@/hooks/use-lab-terminal"
import { cn } from "@/lib/utils"

const LabTerminal = dynamic(
  () => import("@/components/labs/lab-terminal").then((m) => m.LabTerminal),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

type Panel = "terminal" | "files" | "preview" | "resources"

const TABS: { id: Panel; label: string; icon: typeof TerminalSquare }[] = [
  { id: "terminal", label: "Terminal", icon: TerminalSquare },
  { id: "files", label: "Files", icon: FolderTree },
  { id: "preview", label: "Preview", icon: AppWindow },
  { id: "resources", label: "Resources", icon: Boxes },
]

interface LabContainerWorkspaceProps {
  sessionId: string
  taskId: string | undefined
  isTaskPassed: boolean
  isVerifying: boolean
  /** Container port of the lab's running app; 0 hides all preview UI. */
  previewPort: number
  onCheck: (taskId: string) => void
}

// Composes the terminal alongside the file explorer/editor and cluster
// resources panel as tabs. The terminal stays mounted (never unmounted)
// under an `invisible` class when another tab is active — unmounting it
// would tear down its WebSocket connection. The terminal's WebSocket hook is
// owned here (not inside LabTerminal) so its connection status and the task
// Check action can live in this persistent tab-bar header instead of a
// second header duplicated inside the terminal itself.
export function LabContainerWorkspace({
  sessionId,
  taskId,
  isTaskPassed,
  isVerifying,
  previewPort,
  onCheck,
}: LabContainerWorkspaceProps) {
  // Web labs (previewPort > 0) open on the IDE view — editor + live app —
  // since that's where all their work happens; pure terminal labs (k8s)
  // keep the terminal front and center.
  const [activePanel, setActivePanel] = useState<Panel>(
    previewPort > 0 ? "files" : "terminal",
  )
  // Always autoload the file list (not just for web labs) so Ctrl+P quick
  // open can search files before the Files tab is ever visited.
  const filesState = useLabFiles(sessionId, true)
  const resourcesState = useLabResources(sessionId)
  const { containerRef, isConnected, hasGivenUp, reconnectManually, sendText } = useLabTerminal({ sessionId })
  const tabs = TABS.filter((t) => t.id !== "preview" || previewPort > 0)

  function selectPanel(panel: Panel) {
    setActivePanel(panel)
    if (panel === "files" && filesState.files.length === 0) filesState.loadFiles()
    if (panel === "resources" && !resourcesState.hasLoaded) resourcesState.refresh()
  }

  return (
    <div className="flex flex-col h-full">
      {/* Ctrl+P go-to-file; opening a result jumps to the Files panel. */}
      <LabQuickOpen
        files={filesState.files}
        onOpen={(path) => {
          setActivePanel("files")
          filesState.openFile(path)
        }}
      />
      <div aria-label="Lab workspace view" className="flex items-center gap-1 border-b border-border px-2 shrink-0 bg-card" role="tablist">
        {tabs.map(({ id, label, icon: Icon }) => (
          <button
            aria-selected={activePanel === id}
            className={cn(
              // Compact tabs: desktop-only surface, no 44px touch-target here.
              "flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium border-b-2 -mb-px",
              activePanel === id
                ? "border-primary text-primary"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
            key={id}
            role="tab"
            onClick={() => selectPanel(id)}
          >
            <Icon aria-hidden className="h-3.5 w-3.5" />
            {label}
          </button>
        ))}

        <div className="ml-auto flex items-center gap-3 shrink-0">
          <span className="hidden sm:flex items-center gap-1.5 text-xs text-muted-foreground">
            <span
              aria-hidden
              className={cn(
                "h-1.5 w-1.5 rounded-full",
                isConnected ? "bg-success animate-pulse" : "bg-destructive",
              )}
            />
            {isConnected ? "Connected" : "Disconnected"}
          </span>

          {taskId &&
            (isTaskPassed ? (
              <div className="flex h-9 items-center gap-1.5 rounded-md border border-success/20 bg-success/10 px-3">
                <CheckCircle2 aria-hidden className="h-3.5 w-3.5 text-success shrink-0" />
                <span className="text-xs font-medium text-success whitespace-nowrap">Passed</span>
              </div>
            ) : (
              <Button
                aria-label={isVerifying ? "Verifying…" : "Check task"}
                className="gap-1.5"
                disabled={isVerifying}
                size="sm"
                onClick={() => onCheck(taskId)}
              >
                {isVerifying ? (
                  <>
                    <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
                    Checking…
                  </>
                ) : (
                  "Check"
                )}
              </Button>
            ))}
        </div>
      </div>

      <div className="flex-1 min-h-0 relative">
        <div
          className={cn(
            "absolute inset-0",
            activePanel !== "terminal" && "invisible pointer-events-none",
          )}
        >
          <LabTerminal
            containerRef={containerRef}
            hasGivenUp={hasGivenUp}
            isConnected={isConnected}
            reconnectManually={reconnectManually}
            sendText={sendText}
          />
        </div>

        {activePanel === "files" && (
          <div className="absolute inset-0 flex">
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
            <div className="flex-1 overflow-hidden">
              {previewPort > 0 ? (
                <ResizablePanelGroup orientation="horizontal">
                  <ResizablePanel defaultSize="55%" id="lab-ide-editor" minSize="30%">
                    <LabFileEditor
                      activePath={filesState.activePath}
                      isSaving={filesState.isSaving}
                      openFiles={filesState.openFiles}
                      validateResult={filesState.validateResult}
                      onChange={filesState.updateContent}
                      onCloseTab={filesState.closeFile}
                      onSave={filesState.save}
                      onSelectTab={filesState.openFile}
                      onValidate={filesState.validate}
                    />
                  </ResizablePanel>
                  <ResizableHandle withHandle orientation="horizontal" />
                  <ResizablePanel defaultSize="45%" id="lab-ide-preview" minSize="20%">
                    <LabPreviewPane previewPort={previewPort} sessionId={sessionId} />
                  </ResizablePanel>
                </ResizablePanelGroup>
              ) : (
                <LabFileEditor
                  activePath={filesState.activePath}
                  isSaving={filesState.isSaving}
                  openFiles={filesState.openFiles}
                  validateResult={filesState.validateResult}
                  onChange={filesState.updateContent}
                  onCloseTab={filesState.closeFile}
                  onSave={filesState.save}
                  onSelectTab={filesState.openFile}
                  onValidate={filesState.validate}
                />
              )}
            </div>
          </div>
        )}

        {activePanel === "preview" && previewPort > 0 && (
          <div className="absolute inset-0">
            <LabPreviewPane previewPort={previewPort} sessionId={sessionId} />
          </div>
        )}

        {activePanel === "resources" && (
          <div className="absolute inset-0">
            <LabResourcesPanel
              hasLoaded={resourcesState.hasLoaded}
              isLoading={resourcesState.isLoading}
              resources={resourcesState.resources}
              onRefresh={resourcesState.refresh}
            />
          </div>
        )}
      </div>
    </div>
  )
}
