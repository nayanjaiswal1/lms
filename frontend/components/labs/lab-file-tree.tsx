"use client"

import { useState } from "react"
import { ChevronRight, ChevronsDownUp, FilePlus, FolderPlus, Pencil, Trash2 } from "lucide-react"
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
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogCancel,
  AlertDialogAction,
} from "@/components/ui/alert-dialog"
import { cn } from "@/lib/utils"
import { buildFileTree, LAB_FILE_DRAG_MIME } from "@/lib/labs/files"
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

// Inline create/rename input state, consolidated into one object so this
// component stays within the 2-useState-per-component budget. `parent` is
// the folder the entry lives (or will be created) in, empty string for root.
type Draft =
  | { mode: "new-file" | "new-folder"; parent: string; value: string }
  | { mode: "rename"; path: string; parent: string; value: string }
  | null

// All remaining explorer UI state in one object (second of the two allowed
// useStates). VS Code semantics: `focusedPath` is the row keyboard focus /
// selection rests on, `focusedDir` is where the header New File/Folder
// buttons target (last clicked folder or the parent of the last opened
// file), `dropDir` is the folder currently highlighted as a drop target,
// and `confirmDelete` drives the single root-level delete dialog.
interface TreeUI {
  expanded: Set<string>
  focusedDir: string
  focusedPath: string | null
  dropDir: string | null
  confirmDelete: { path: string; isDir: boolean } | null
}

function parentOf(path: string): string {
  const lastSlash = path.lastIndexOf("/")
  return lastSlash === -1 ? "" : path.slice(0, lastSlash)
}

// The visible rows in render order — what ArrowUp/ArrowDown walk over,
// exactly like VS Code's list-backed tree.
function flattenVisible(nodes: FileTreeNode[], expanded: Set<string>, out: FileTreeNode[] = []): FileTreeNode[] {
  for (const node of nodes) {
    out.push(node)
    if (node.type === "dir" && expanded.has(node.path) && node.children) {
      flattenVisible(node.children, expanded, out)
    }
  }
  return out
}

// Autofocus the draft input and, for renames, pre-select the basename
// (everything before the last dot) so typing replaces the name but keeps
// the extension — VS Code's rename behavior. Guarded by a data attribute
// because ref callbacks re-run on every render.
function focusDraftInput(el: HTMLInputElement | null) {
  if (!el || el.dataset.autofocused) return
  el.dataset.autofocused = "1"
  el.focus()
  const dot = el.value.lastIndexOf(".")
  el.setSelectionRange(0, dot > 0 ? dot : el.value.length)
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
  const [ui, setUi] = useState<TreeUI>(() => ({
    expanded: new Set<string>(),
    focusedDir: "",
    focusedPath: null,
    dropDir: null,
    confirmDelete: null,
  }))

  const tree = buildFileTree(files)

  function toggleExpanded(path: string) {
    setUi((prev) => {
      const expanded = new Set(prev.expanded)
      if (expanded.has(path)) expanded.delete(path)
      else expanded.add(path)
      return { ...prev, expanded, focusedDir: path, focusedPath: path }
    })
  }

  function openFile(path: string) {
    setUi((prev) => ({ ...prev, focusedDir: parentOf(path), focusedPath: path }))
    onOpen(path)
  }

  function collapseAll() {
    setUi((prev) => ({ ...prev, expanded: new Set<string>(), focusedDir: "", focusedPath: null }))
  }

  function startCreate(mode: "new-file" | "new-folder", parent: string) {
    if (parent) {
      setUi((prev) => ({ ...prev, expanded: new Set(prev.expanded).add(parent) }))
    }
    setDraft({ mode, parent, value: "" })
  }

  function startRename(node: FileTreeNode) {
    setDraft({ mode: "rename", path: node.path, parent: parentOf(node.path), value: node.name })
  }

  function requestDelete(node: FileTreeNode) {
    setUi((prev) => ({ ...prev, confirmDelete: { path: node.path, isDir: node.type === "dir" } }))
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
    else if (draft.mode === "rename") {
      const from = draft.path
      onRename(from, fullPath)
      // Keep expansion/focus pointing at the renamed folder (and anything
      // under it) so the tree doesn't collapse after a rename.
      setUi((prev) => {
        const remap = (p: string) =>
          p === from ? fullPath : p.startsWith(`${from}/`) ? fullPath + p.slice(from.length) : p
        return {
          ...prev,
          expanded: new Set([...prev.expanded].map(remap)),
          focusedDir: remap(prev.focusedDir),
          focusedPath: prev.focusedPath === null ? null : remap(prev.focusedPath),
        }
      })
    }
    setDraft(null)
  }

  // Moves a dragged file/folder into targetDir by reusing the rename/move
  // endpoint — the backend's `mv` already relocates directories with all
  // their contents in one call.
  function handleDrop(e: React.DragEvent, targetDir: string) {
    e.preventDefault()
    setUi((prev) => (prev.dropDir === null ? prev : { ...prev, dropDir: null }))
    const from = e.dataTransfer.getData(LAB_FILE_DRAG_MIME)
    if (!from) return
    if (targetDir === from || targetDir.startsWith(`${from}/`)) return
    if (parentOf(from) === targetDir) return
    const name = from.includes("/") ? from.slice(from.lastIndexOf("/") + 1) : from
    onRename(from, targetDir ? `${targetDir}/${name}` : name)
  }

  function setDropDir(dir: string | null) {
    setUi((prev) => (prev.dropDir === dir ? prev : { ...prev, dropDir: dir }))
  }

  // Single keydown handler on the tree container (VS Code's list keyboard
  // model): arrows move a focus cursor over the visible rows, Left/Right
  // collapse/expand, Enter/Space activates, F2 renames, Delete deletes.
  function onTreeKeyDown(e: React.KeyboardEvent) {
    if (draft || isBusy) return
    const rows = flattenVisible(tree, ui.expanded)
    if (rows.length === 0) return
    const idx = ui.focusedPath === null ? -1 : rows.findIndex((r) => r.path === ui.focusedPath)
    const node = idx === -1 ? null : rows[idx]

    const focusRow = (i: number) => {
      const target = rows[Math.max(0, Math.min(rows.length - 1, i))]
      setUi((prev) => ({
        ...prev,
        focusedPath: target.path,
        focusedDir: target.type === "dir" ? target.path : parentOf(target.path),
      }))
    }

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault()
        focusRow(idx + 1)
        break
      case "ArrowUp":
        e.preventDefault()
        focusRow(idx <= 0 ? 0 : idx - 1)
        break
      case "ArrowRight":
        e.preventDefault()
        if (!node) focusRow(0)
        else if (node.type === "dir" && !ui.expanded.has(node.path)) toggleExpanded(node.path)
        else if (node.type === "dir" && node.children && node.children.length > 0) focusRow(idx + 1)
        break
      case "ArrowLeft": {
        e.preventDefault()
        if (!node) {
          focusRow(0)
          break
        }
        if (node.type === "dir" && ui.expanded.has(node.path)) {
          toggleExpanded(node.path)
        } else {
          const parent = parentOf(node.path)
          if (parent !== "") {
            const parentIdx = rows.findIndex((r) => r.path === parent)
            if (parentIdx !== -1) focusRow(parentIdx)
          }
        }
        break
      }
      case "Home":
        e.preventDefault()
        focusRow(0)
        break
      case "End":
        e.preventDefault()
        focusRow(rows.length - 1)
        break
      case "Enter":
      case " ":
        e.preventDefault()
        if (!node) break
        if (node.type === "dir") toggleExpanded(node.path)
        else openFile(node.path)
        break
      case "F2":
        e.preventDefault()
        if (node) startRename(node)
        break
      case "Delete":
        e.preventDefault()
        if (node) requestDelete(node)
        break
    }
  }

  // Vertical indent guides, one per ancestor level, matching VS Code's
  // tree guides. 14px per level (10px guide column + 4px flex gap), so no
  // unbounded inline padding style is needed anymore.
  function renderGuides(depth: number) {
    return Array.from({ length: depth }, (_, i) => (
      <span aria-hidden className="w-2.5 shrink-0 self-stretch border-l border-border/60" key={i} />
    ))
  }

  function renderDraftRow(depth: number) {
    if (!draft) return null
    const isFolder = draft.mode === "new-folder"
    // Live icon preview: the icon tracks the typed extension, like VS Code.
    const Icon = getFileIcon(draft.value || "file", isFolder ? "dir" : "file")
    return (
      <div className="flex items-center gap-1 py-0.5 pl-2 pr-2">
        {renderGuides(depth)}
        <span aria-hidden className="w-4 shrink-0" />
        <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
        <Input
          className="h-6 flex-1 rounded-sm px-1 text-sm"
          placeholder={isFolder ? "folder name" : "file name"}
          ref={focusDraftInput}
          value={draft.value}
          onBlur={(e) => {
            // Escape/Enter mark the input done before this fires; without
            // the guard a commit would run twice (or after a cancel).
            if (e.currentTarget.dataset.done !== "1") submitDraft()
          }}
          onChange={(e) => setDraft((prev) => (prev ? { ...prev, value: e.target.value } : prev))}
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              e.currentTarget.dataset.done = "1"
              setDraft(null)
            } else if (e.key === "Enter") {
              e.preventDefault()
              e.currentTarget.dataset.done = "1"
              submitDraft()
            }
          }}
        />
      </div>
    )
  }

  function renderNode(node: FileTreeNode, depth: number) {
    const isDir = node.type === "dir"
    const isOpenDir = isDir && ui.expanded.has(node.path)
    const Icon = getFileIcon(node.name, node.type, isOpenDir)
    // Dropping onto a file targets its parent folder (VS Code behavior)
    // instead of falling through to the root drop zone.
    const dropTargetDir = isDir ? node.path : parentOf(node.path)
    const isSelected = !isDir && selectedPath === node.path
    const isFocused = ui.focusedPath === node.path
    const isDropTarget = ui.dropDir === node.path

    if (draft?.mode === "rename" && draft.path === node.path) {
      return <div key={node.path}>{renderDraftRow(depth)}</div>
    }

    const row = (
      // eslint-disable-next-line jsx-a11y/click-events-have-key-events -- keyboard interaction (arrows/Enter/F2/Delete) is handled by the tree container's roving-focus keydown, per the WAI-ARIA tree pattern
      <div
        draggable
        aria-current={isSelected ? "true" : undefined}
        aria-expanded={isDir ? isOpenDir : undefined}
        aria-selected={isFocused || isSelected}
        className={cn(
          // Compact flat rows like VS Code's explorer; desktop-only surface,
          // so no 44px touch-target enforcement.
          "group flex items-center gap-1 py-0.5 pl-2 pr-2 text-sm cursor-pointer select-none",
          isSelected ? "bg-primary/10 text-primary" : "text-foreground hover:bg-muted/70",
          isFocused && !isSelected && "bg-muted",
          isDropTarget && "bg-primary/10 ring-1 ring-inset ring-primary/50",
        )}
        role="treeitem"
        tabIndex={-1}
        title={node.path}
        onClick={() => (isDir ? toggleExpanded(node.path) : openFile(node.path))}
        onContextMenu={() => setUi((prev) => ({ ...prev, focusedPath: node.path }))}
        onDragEnd={() => setDropDir(null)}
        onDragEnter={(e) => {
          e.stopPropagation()
          setDropDir(dropTargetDir)
        }}
        onDragOver={(e) => {
          e.preventDefault()
          e.dataTransfer.dropEffect = "move"
        }}
        onDragStart={(e) => {
          e.dataTransfer.setData(LAB_FILE_DRAG_MIME, node.path)
          e.dataTransfer.effectAllowed = "move"
        }}
        onDrop={(e) => {
          // Stop the drop from also bubbling to the tree's root drop zone —
          // otherwise a single drop fires a second, now-stale move attempt.
          e.stopPropagation()
          handleDrop(e, dropTargetDir)
        }}
      >
        {renderGuides(depth)}
        {/* Chevron slot: rotating chevron for folders, spacer for files so names align like VS Code. */}
        {isDir ? (
          <ChevronRight
            aria-hidden
            className={cn(
              "h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-fast",
              isOpenDir && "rotate-90",
            )}
          />
        ) : (
          <span aria-hidden className="w-4 shrink-0" />
        )}
        <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
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
            <ContextMenuItem onSelect={() => startRename(node)}>
              <Pencil aria-hidden className="h-3.5 w-3.5" />
              Rename
              <span className="ml-auto text-xs text-muted-foreground">F2</span>
            </ContextMenuItem>
            <ContextMenuItem variant="destructive" onSelect={() => requestDelete(node)}>
              <Trash2 aria-hidden className="h-3.5 w-3.5" />
              Delete
              <span className="ml-auto text-xs text-muted-foreground">Del</span>
            </ContextMenuItem>
          </ContextMenuContent>
        </ContextMenu>

        {isDir && isOpenDir && (
          <>
            {draft !== null &&
              draft.mode !== "rename" &&
              draft.parent === node.path &&
              renderDraftRow(depth + 1)}
            {node.children?.map((child) => renderNode(child, depth + 1))}
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
            onClick={() => startCreate("new-file", ui.focusedDir)}
          >
            <FilePlus aria-hidden className="h-3.5 w-3.5" />
          </Button>
          <Button
            aria-label="New folder"
            className="h-6 w-6 p-0"
            disabled={isBusy}
            size="sm"
            variant="ghost"
            onClick={() => startCreate("new-folder", ui.focusedDir)}
          >
            <FolderPlus aria-hidden className="h-3.5 w-3.5" />
          </Button>
          <Button
            aria-label="Collapse folders"
            className="h-6 w-6 p-0"
            disabled={isBusy}
            size="sm"
            variant="ghost"
            onClick={collapseAll}
          >
            <ChevronsDownUp aria-hidden className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>

      <ScrollArea className="flex-1" onDragOver={(e) => e.preventDefault()} onDrop={(e) => handleDrop(e, "")}>
        {/* Clicking empty space below the rows re-targets New File/Folder at the root, like VS Code. */}
        <div
          className={cn(
            "flex h-full flex-col p-1 outline-none",
            ui.dropDir === "" && "bg-primary/5",
          )}
          role="tree"
          tabIndex={0}
          onClick={(e) => {
            if (e.target === e.currentTarget) setUi((prev) => ({ ...prev, focusedDir: "" }))
          }}
          onDragEnter={(e) => {
            // Row drag-enters stop propagation, so reaching here means the
            // drag is over empty space — target the root.
            if (e.target === e.currentTarget) setDropDir("")
          }}
          onDragLeave={(e) => {
            if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setDropDir(null)
          }}
          onKeyDown={onTreeKeyDown}
        >
          {draft !== null && draft.mode !== "rename" && draft.parent === "" && renderDraftRow(0)}

          {tree.length === 0 && !draft && (
            <p className="px-3 py-4 text-xs text-muted-foreground text-center">
              No files yet. Create one to get started.
            </p>
          )}

          {tree.map((node) => renderNode(node, 0))}
        </div>
      </ScrollArea>

      {/* One shared confirm dialog (driven by ui.confirmDelete) instead of a
          dialog per row, so the Delete key and the context menu share it. */}
      <AlertDialog
        open={ui.confirmDelete !== null}
        onOpenChange={(open) => {
          if (!open) setUi((prev) => ({ ...prev, confirmDelete: null }))
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete {ui.confirmDelete?.path}?</AlertDialogTitle>
            <AlertDialogDescription>
              {ui.confirmDelete?.isDir
                ? "This removes the folder and everything inside it from your lab environment. This action cannot be undone."
                : "This removes the file from your lab environment. This action cannot be undone."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                const target = ui.confirmDelete
                setUi((prev) => ({ ...prev, confirmDelete: null }))
                if (target) onDelete(target.path)
              }}
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
