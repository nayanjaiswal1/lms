"use client"

import { useState } from "react"
import dynamic from "next/dynamic"
import { TerminalSquare, FolderTree, Boxes, Loader2, CheckCircle2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { LabFileTree } from "@/components/labs/lab-file-tree"
import { LabFileEditor } from "@/components/labs/lab-file-editor"
import { LabResourcesPanel } from "@/components/labs/lab-resources-panel"
import { useLabFiles } from "@/hooks/use-lab-files"
import { useLabResources } from "@/hooks/use-lab-resources"
import { useLabTerminal } from "@/hooks/use-lab-terminal"
import { cn } from "@/lib/utils"

const LabTerminal = dynamic(
  () => import("@/components/labs/lab-terminal").then((m) => m.LabTerminal),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

type Panel = "terminal" | "files" | "resources"

const TABS: { id: Panel; label: string; icon: typeof TerminalSquare }[] = [
  { id: "terminal", label: "Terminal", icon: TerminalSquare },
  { id: "files", label: "Files", icon: FolderTree },
  { id: "resources", label: "Resources", icon: Boxes },
]

interface LabContainerWorkspaceProps {
  sessionId: string
  taskId: string | undefined
  isTaskPassed: boolean
  isVerifying: boolean
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
  onCheck,
}: LabContainerWorkspaceProps) {
  const [activePanel, setActivePanel] = useState<Panel>("terminal")
  const filesState = useLabFiles(sessionId)
  const resourcesState = useLabResources(sessionId)
  const { containerRef, isConnected, reconnectManually } = useLabTerminal({ sessionId })

  function selectPanel(panel: Panel) {
    setActivePanel(panel)
    if (panel === "files" && filesState.files.length === 0) filesState.loadFiles()
    if (panel === "resources" && !resourcesState.hasLoaded) resourcesState.refresh()
  }

  return (
    <div className="flex flex-col h-full">
      <div aria-label="Lab workspace view" className="flex items-center gap-1 border-b border-border px-2 shrink-0 bg-card" role="tablist">
        {TABS.map(({ id, label, icon: Icon }) => (
          <button
            aria-selected={activePanel === id}
            className={cn(
              "flex items-center gap-1.5 px-3 py-2 text-xs font-medium border-b-2 -mb-px touch-target",
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
            isConnected={isConnected}
            reconnectManually={reconnectManually}
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
            </div>
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
