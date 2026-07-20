"use client"

import type { ReactNode } from "react"
import { Search } from "lucide-react"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"

export interface MenuAction {
  label: string
  shortcut?: string
  onClick: () => void
  disabled?: boolean
}

interface LabMenuBarProps {
  fileActions: MenuAction[]
  viewActions: MenuAction[]
  runActions: MenuAction[]
  terminalActions: MenuAction[]
}

// Redispatches a synthetic keydown at the focused element so Monaco's own
// registered keybindings fire — document.execCommand desyncs from Monaco's
// internal undo stack and would silently break Undo/Redo.
function fireEditorCommand(key: string) {
  document.activeElement?.dispatchEvent(
    new KeyboardEvent("keydown", { key, ctrlKey: true, metaKey: true, bubbles: true, cancelable: true }),
  )
}

// Reuses LabQuickOpen's existing capture-phase Ctrl+P listener instead of
// adding controlled open/onOpenChange props to that component.
function triggerGoToFile() {
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "p", ctrlKey: true, bubbles: true, cancelable: true }))
}

function MenuButton({ label, children }: { label: string; children: ReactNode }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="rounded-sm px-2 py-1 text-xs text-foreground/80 outline-none hover:bg-accent hover:text-accent-foreground data-[state=open]:bg-accent data-[state=open]:text-accent-foreground">
        {label}
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="min-w-56">
        {children}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function ActionItems({ actions }: { actions: MenuAction[] }) {
  return (
    <>
      {actions.map((action) => (
        <DropdownMenuItem key={action.label} disabled={action.disabled} onClick={action.onClick}>
          {action.label}
          {action.shortcut && <DropdownMenuShortcut>{action.shortcut}</DropdownMenuShortcut>}
        </DropdownMenuItem>
      ))}
    </>
  )
}

/**
 * VS Code-style title bar: File/Edit/View/Go/Run/Terminal menus plus the
 * "Go to File" search box. Edit/Go are generic (they dispatch the same key
 * events Monaco and LabQuickOpen already listen for); File/View/Run/Terminal
 * are capability-driven props since LabContainerWorkspace and
 * SandboxWorkspace expose different actions.
 */
export function LabMenuBar({ fileActions, viewActions, runActions, terminalActions }: LabMenuBarProps) {
  return (
    <div className="flex h-8 shrink-0 items-center gap-0.5 border-b border-border bg-card px-2">
      <MenuButton label="File">
        <ActionItems actions={fileActions} />
      </MenuButton>

      <MenuButton label="Edit">
        <DropdownMenuItem onClick={() => fireEditorCommand("z")}>
          Undo
          <DropdownMenuShortcut>Ctrl+Z</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => fireEditorCommand("y")}>
          Redo
          <DropdownMenuShortcut>Ctrl+Y</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => fireEditorCommand("x")}>
          Cut
          <DropdownMenuShortcut>Ctrl+X</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => fireEditorCommand("c")}>
          Copy
          <DropdownMenuShortcut>Ctrl+C</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => fireEditorCommand("v")}>
          Paste
          <DropdownMenuShortcut>Ctrl+V</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => fireEditorCommand("f")}>
          Find
          <DropdownMenuShortcut>Ctrl+F</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => fireEditorCommand("h")}>
          Replace
          <DropdownMenuShortcut>Ctrl+H</DropdownMenuShortcut>
        </DropdownMenuItem>
      </MenuButton>

      <MenuButton label="View">
        <ActionItems actions={viewActions} />
      </MenuButton>

      <MenuButton label="Go">
        <DropdownMenuItem onClick={triggerGoToFile}>
          Go to File...
          <DropdownMenuShortcut>Ctrl+P</DropdownMenuShortcut>
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => fireEditorCommand("g")}>
          Go to Line/Column...
          <DropdownMenuShortcut>Ctrl+G</DropdownMenuShortcut>
        </DropdownMenuItem>
      </MenuButton>

      <MenuButton label="Run">
        <ActionItems actions={runActions} />
      </MenuButton>

      <MenuButton label="Terminal">
        <ActionItems actions={terminalActions} />
      </MenuButton>

      <button
        aria-label="Go to file"
        className="ml-4 flex h-6 w-full max-w-sm items-center gap-2 rounded-sm border border-border bg-background px-2.5 text-xs text-muted-foreground hover:border-ring"
        type="button"
        onClick={triggerGoToFile}
      >
        <Search aria-hidden className="h-3 w-3 shrink-0" />
        <span className="flex-1 truncate text-left">Go to File</span>
        <kbd className="hidden text-[10px] text-muted-foreground/70 sm:inline">Ctrl+P</kbd>
      </button>
    </div>
  )
}
