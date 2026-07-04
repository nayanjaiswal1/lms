"use client"

import { useState } from "react"
import { FilePlus, FolderPlus, Pencil, Trash2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import {
  ContextMenu,
  ContextMenuTrigger,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
} from "@/components/ui/context-menu"
import {
  AlertDialog,
  AlertDialogTrigger,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
  AlertDialogAction,
} from "@/components/ui/alert-dialog"
import { cn } from "@/lib/utils"
import { buildFileTree } from "@/lib/labs/files"
import { getFileIcon } from "@/lib/labs/file-icon"
import type { LabFileEntry, FileTreeNode } from "@/lib/labs/files"

interface LabFileTreeProps {
  files: LabFileEntry[]
  selectedPath: string | undefined
  isBusy: boolean
  onOpen: (path: string) => void
  onCreate: (path: string) => void
  onCreateFolder: (path: string) => void
  onRename: (from: string, to: string) => void
  onDelete: (path: string) => void
}

// Drag-and-drop payload MIME type, namespaced so the tree only reacts to
// drags it started itself (not files dragged in from the OS or other tabs).
const DRAG_MIME = "application/x-mindforge-lab-path"

// Inline create/rename input state, consolidated into one object so this
// component stays within the 2-useState-per-component budget. `parent` is
// the folder the entry lives (or will be created) in, empty string for root.
type Draft =
  | { mode: "new-file" | "new-folder"; parent: string; value: string }
  | { mode: "rename"; path: string; parent: string; value: string }
  | null

function parentOf(path: string): string {
  const lastSlash = path.lastIndexOf("/")
  return lastSlash === -1 ? "" : path.slice(0, lastSlash)
}

export function LabFileTree({
  files,
  selectedPath,
  isBusy,
  onOpen,
  onCreate,
  onCreateFolder,
  onRename,
  onDelete,
}: LabFileTreeProps) {
  const [draft, setDraft] = useState<Draft>(null)
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())

  const tree = buildFileTree(files)

  function toggleExpanded(path: string) {
    setExpanded((prev) => {
      const next = new Set(prev)
      if (next.has(path)) next.delete(path)
      else next.add(path)
      return next
    })
  }

  function startCreate(mode: "new-file" | "new-folder", parent: string) {
    if (parent) setExpanded((prev) => new Set(prev).add(parent))
    setDraft({ mode, parent, value: "" })
  }

  function submitDraft() {
    if (!draft || draft.value.trim() === "") {
      setDraft(null)
      return
    }
    const name = draft.value.trim()
    const fullPath = draft.parent ? `${draft.parent}/${name}` : name
    if (draft.mode === "new-file") onCreate(fullPath)
    else if (draft.mode === "new-folder") onCreateFolder(fullPath)
    else if (draft.mode === "rename") onRename(draft.path, fullPath)
    setDraft(null)
  }

  // Moves a dragged file/folder into targetDir by reusing the rename/move
  // endpoint — the backend's `mv` already relocates directories with all
  // their contents in one call.
  function handleDrop(e: React.DragEvent, targetDir: string) {
    e.preventDefault()
    const from = e.dataTransfer.getData(DRAG_MIME)
    if (!from) return
    if (targetDir === from || targetDir.startsWith(`${from}/`)) return
    if (parentOf(from) === targetDir) return
    const name = from.includes("/") ? from.slice(from.lastIndexOf("/") + 1) : from
    onRename(from, targetDir ? `${targetDir}/${name}` : name)
  }

  function renderDraftInput(placeholder: string) {
    return (
      <form
        className="px-2 py-1"
        onSubmit={(e) => {
          e.preventDefault()
          submitDraft()
        }}
      >
        <Input
          className="h-7 text-xs"
          placeholder={placeholder}
          ref={(el) => el?.focus()}
          value={draft?.value ?? ""}
          onBlur={submitDraft}
          onChange={(e) => setDraft((prev) => (prev ? { ...prev, value: e.target.value } : prev))}
        />
      </form>
    )
  }

  function renderNode(node: FileTreeNode, depth: number) {
    const isDir = node.type === "dir"
    const isOpenDir = isDir && expanded.has(node.path)
    const Icon = getFileIcon(node.name, node.type, isOpenDir)
    const indent = 8 + depth * 14

    if (draft?.mode === "rename" && draft.path === node.path) {
      return (
        <div
          key={node.path}
          // eslint-disable-next-line no-restricted-syntax -- indent depends on recursive tree depth, which is unbounded and can't be expressed as a static Tailwind class
          style={{ paddingLeft: indent }}
        >
          {renderDraftInput(node.name)}
        </div>
      )
    }

    const row = (
      <div
        draggable
        aria-current={!isDir && selectedPath === node.path ? "true" : undefined}
        className={cn(
          "group flex items-center gap-1.5 rounded-md py-1.5 pr-1 text-sm cursor-pointer touch-target",
          !isDir && selectedPath === node.path
            ? "bg-primary/10 text-primary"
            : "text-foreground hover:bg-muted",
        )}
        role="button"
        // eslint-disable-next-line no-restricted-syntax -- indent depends on recursive tree depth, which is unbounded and can't be expressed as a static Tailwind class
        style={{ paddingLeft: indent }}
        tabIndex={0}
        onClick={() => (isDir ? toggleExpanded(node.path) : onOpen(node.path))}
        onDragOver={isDir ? (e) => e.preventDefault() : undefined}
        onDragStart={(e) => {
          e.dataTransfer.setData(DRAG_MIME, node.path)
          e.dataTransfer.effectAllowed = "move"
        }}
        onDrop={
          isDir
            ? (e) => {
                // Stop the drop from also bubbling to the tree's root drop
                // zone — otherwise a single drop onto a folder fires a
                // second, now-stale move attempt on the file's old path.
                e.stopPropagation()
                handleDrop(e, node.path)
              }
            : undefined
        }
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault()
            if (isDir) toggleExpanded(node.path)
            else onOpen(node.path)
          }
        }}
      >
        <Icon aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
        <span className="flex-1 truncate">{node.name}</span>
      </div>
    )

    return (
      <div key={node.path}>
        <ContextMenu>
          <ContextMenuTrigger asChild>{row}</ContextMenuTrigger>
          <ContextMenuContent>
            {isDir && (
              <>
                <ContextMenuItem onSelect={() => startCreate("new-file", node.path)}>
                  <FilePlus aria-hidden className="h-3.5 w-3.5" />
                  New File
                </ContextMenuItem>
                <ContextMenuItem onSelect={() => startCreate("new-folder", node.path)}>
                  <FolderPlus aria-hidden className="h-3.5 w-3.5" />
                  New Folder
                </ContextMenuItem>
                <ContextMenuSeparator />
              </>
            )}
            <ContextMenuItem
              onSelect={() =>
                setDraft({ mode: "rename", path: node.path, parent: parentOf(node.path), value: node.name })
              }
            >
              <Pencil aria-hidden className="h-3.5 w-3.5" />
              Rename
            </ContextMenuItem>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <ContextMenuItem variant="destructive" onSelect={(e) => e.preventDefault()}>
                  <Trash2 aria-hidden className="h-3.5 w-3.5" />
                  Delete
                </ContextMenuItem>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Delete {node.path}?</AlertDialogTitle>
                  <AlertDialogDescription>
                    {isDir
                      ? "This removes the folder and everything inside it from your lab environment. This action cannot be undone."
                      : "This removes the file from your lab environment. This action cannot be undone."}
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction
                    className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    onClick={() => onDelete(node.path)}
                  >
                    Delete
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </ContextMenuContent>
        </ContextMenu>

        {isDir && isOpenDir && (
          <>
            {node.children?.map((child) => renderNode(child, depth + 1))}
            {draft?.mode !== "rename" && draft?.parent === node.path && (
              <div
                // eslint-disable-next-line no-restricted-syntax -- indent depends on recursive tree depth, which is unbounded and can't be expressed as a static Tailwind class
                style={{ paddingLeft: indent + 14 }}
              >
                {renderDraftInput(draft.mode === "new-folder" ? "new-folder" : "new-file.yaml")}
              </div>
            )}
          </>
        )}
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between px-3 py-2 border-b border-border shrink-0">
        <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
          Files
        </span>
        <div className="flex items-center gap-0.5">
          <Button
            aria-label="New file"
            className="h-6 w-6 p-0"
            disabled={isBusy}
            size="sm"
            variant="ghost"
            onClick={() => startCreate("new-file", "")}
          >
            <FilePlus aria-hidden className="h-3.5 w-3.5" />
          </Button>
          <Button
            aria-label="New folder"
            className="h-6 w-6 p-0"
            disabled={isBusy}
            size="sm"
            variant="ghost"
            onClick={() => startCreate("new-folder", "")}
          >
            <FolderPlus aria-hidden className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>

      <ScrollArea className="flex-1" onDragOver={(e) => e.preventDefault()} onDrop={(e) => handleDrop(e, "")}>
        <div className="flex flex-col p-1">
          {draft?.mode !== "rename" && draft?.parent === "" && renderDraftInput(draft.mode === "new-folder" ? "new-folder" : "new-file.yaml")}

          {tree.length === 0 && !draft && (
            <p className="px-3 py-4 text-xs text-muted-foreground text-center">
              No files yet. Create one to get started.
            </p>
          )}

          {tree.map((node) => renderNode(node, 0))}
        </div>
      </ScrollArea>
    </div>
  )
}
