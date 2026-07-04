"use client"

import { X } from "lucide-react"
import { getFileIcon } from "@/lib/labs/file-icon"
import { cn } from "@/lib/utils"

interface OpenFile {
  path: string
  content: string
  dirty: boolean
}

interface LabFileTabsProps {
  openFiles: OpenFile[]
  activePath: string | null
  onSelect: (path: string) => void
  onClose: (path: string) => void
}

function basename(path: string): string {
  const idx = path.lastIndexOf("/")
  return idx === -1 ? path : path.slice(idx + 1)
}

export function LabFileTabs({ openFiles, activePath, onSelect, onClose }: LabFileTabsProps) {
  if (openFiles.length === 0) return null

  return (
    <div
      aria-label="Open files"
      className="flex items-center overflow-x-auto border-b border-border shrink-0 bg-muted/30"
      role="tablist"
    >
      {openFiles.map((file) => {
        const isActive = file.path === activePath
        const Icon = getFileIcon(file.path, "file")
        return (
          <div
            aria-selected={isActive}
            className={cn(
              "group flex max-w-48 shrink-0 items-center gap-1.5 border-r border-border px-3 py-2 text-xs cursor-pointer",
              isActive
                ? "bg-background text-foreground border-t-2 border-t-primary -mt-px"
                : "text-muted-foreground hover:bg-muted/60",
            )}
            key={file.path}
            role="tab"
            tabIndex={0}
            title={file.path}
            onClick={() => onSelect(file.path)}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault()
                onSelect(file.path)
              }
            }}
          >
            <Icon aria-hidden className="h-3.5 w-3.5 shrink-0" />
            <span className="flex-1 truncate">{basename(file.path)}</span>
            <button
              aria-label={`Close ${basename(file.path)}${file.dirty ? " (unsaved changes)" : ""}`}
              className="relative flex h-5 w-5 shrink-0 items-center justify-center rounded hover:bg-muted touch-target"
              type="button"
              onClick={(e) => {
                e.stopPropagation()
                onClose(file.path)
              }}
            >
              {!isActive && (
                <span
                  aria-hidden
                  className={cn(
                    "absolute inset-0 m-auto h-1.5 w-1.5 rounded-full bg-primary transition-opacity duration-fast group-hover:opacity-0",
                    file.dirty ? "opacity-100" : "opacity-0",
                  )}
                />
              )}
              <X
                aria-hidden
                className={cn(
                  "h-3 w-3 transition-opacity duration-fast group-hover:opacity-100",
                  isActive ? "opacity-100" : "opacity-0",
                )}
              />
            </button>
          </div>
        )
      })}
    </div>
  )
}
