"use client"

import { useState, useEffect, useRef } from "react"
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { getFileIcon } from "@/lib/labs/file-icon"
import { cn } from "@/lib/utils"
import type { LabFileEntry } from "@/lib/labs/files"

const MAX_RESULTS = 15

interface LabQuickOpenProps {
  files: LabFileEntry[]
  onOpen: (path: string) => void
}

function basename(path: string): string {
  const idx = path.lastIndexOf("/")
  return idx === -1 ? path : path.slice(idx + 1)
}

function dirname(path: string): string {
  const idx = path.lastIndexOf("/")
  return idx === -1 ? "" : path.slice(0, idx)
}

/**
 * VS Code's Ctrl+P "Go to File" for the lab IDE. Self-contained: owns its
 * open/query state and the global shortcut listener; hosts just mount it with
 * the file list and an open callback.
 */
export function LabQuickOpen({ files, onOpen }: LabQuickOpenProps) {
  // Single state object (open + query + highlighted row) to stay inside the
  // 2-useState budget and reset the highlight atomically with each keystroke.
  const [state, setState] = useState({ open: false, query: "", index: 0 })
  const listRef = useRef<HTMLUListElement>(null)

  // Global Ctrl+P/Cmd+P. Capture phase so it wins over Monaco's key handling
  // when the editor has focus; no non-effect equivalent for window listeners.
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && !e.shiftKey && !e.altKey && e.key.toLowerCase() === "p") {
        e.preventDefault()
        setState({ open: true, query: "", index: 0 })
      }
    }
    window.addEventListener("keydown", onKeyDown, true)
    return () => window.removeEventListener("keydown", onKeyDown, true)
  }, [])

  const query = state.query.trim().toLowerCase()
  const matches = files
    .filter((f) => f.type === "file" && f.path.toLowerCase().includes(query))
    // Filename hits above path-only hits, then shorter paths first — the
    // ponytail version of VS Code's fuzzy scoring.
    .sort((a, b) => {
      const aName = basename(a.path).toLowerCase().includes(query) ? 0 : 1
      const bName = basename(b.path).toLowerCase().includes(query) ? 0 : 1
      return aName - bName || a.path.length - b.path.length
    })
    .slice(0, MAX_RESULTS)

  const highlighted = Math.min(state.index, Math.max(matches.length - 1, 0))

  function openResult(path: string) {
    onOpen(path)
    setState({ open: false, query: "", index: 0 })
  }

  function onInputKeyDown(e: React.KeyboardEvent) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
      const delta = e.key === "ArrowDown" ? 1 : -1
      const next = (highlighted + delta + matches.length) % Math.max(matches.length, 1)
      setState((prev) => ({ ...prev, index: next }))
      listRef.current?.children[next]?.scrollIntoView({ block: "nearest" })
    } else if (e.key === "Enter" && matches[highlighted]) {
      e.preventDefault()
      openResult(matches[highlighted].path)
    }
  }

  return (
    <Dialog open={state.open} onOpenChange={(open) => setState({ open, query: "", index: 0 })}>
      <DialogContent className="top-24 translate-y-0 gap-0 p-2 sm:max-w-lg">
        <DialogTitle className="sr-only">Go to file</DialogTitle>
        {/* No autoFocus needed: Radix DialogContent focuses the first focusable element on open. */}
        <Input
          className="h-8 text-sm"
          placeholder="Go to file… (↑↓ to navigate, Enter to open)"
          value={state.query}
          onChange={(e) => setState((prev) => ({ ...prev, query: e.target.value, index: 0 }))}
          onKeyDown={onInputKeyDown}
        />
        <ul className="mt-2 max-h-72 overflow-y-auto" ref={listRef}>
          {matches.length === 0 && (
            <li className="px-2 py-3 text-center text-xs text-muted-foreground">
              No matching files
            </li>
          )}
          {matches.map((file, i) => {
            const Icon = getFileIcon(file.path, "file")
            const dir = dirname(file.path)
            return (
              <li key={file.path}>
                <button
                  className={cn(
                    "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm",
                    i === highlighted ? "bg-primary/10 text-primary" : "hover:bg-muted",
                  )}
                  type="button"
                  onClick={() => openResult(file.path)}
                  onMouseEnter={() => setState((prev) => ({ ...prev, index: i }))}
                >
                  <Icon aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                  <span className="shrink-0">{basename(file.path)}</span>
                  {dir && <span className="truncate text-xs text-muted-foreground">{dir}</span>}
                </button>
              </li>
            )
          })}
        </ul>
      </DialogContent>
    </Dialog>
  )
}
