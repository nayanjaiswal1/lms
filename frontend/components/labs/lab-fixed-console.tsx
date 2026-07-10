"use client"

import { useRef, useState, type PointerEvent, type ReactNode } from "react"
import { createPortal } from "react-dom"
import { ChevronDown, ChevronUp, TerminalSquare } from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

export const LAB_CONSOLE_DEFAULT_HEIGHT = 340
export const LAB_CONSOLE_COLLAPSED_HEIGHT = 44

const MIN_HEIGHT = 220
const MAX_HEIGHT_RATIO = 0.85

interface LabFixedConsoleProps {
  title: string
  children: ReactNode
  onHeightChange?: (px: number) => void
}

// Google Cloud Shell style: a full-viewport-width panel pinned to the bottom
// of the browser window. Rendered via a portal to <body> so it escapes the
// article/sidebar layout instead of being boxed into the page's own scroll
// column. The top edge is drag-resizable; the chevron collapses it to just
// its header bar.
export function LabFixedConsole({ title, children, onHeightChange }: LabFixedConsoleProps) {
  const [height, setHeight] = useState(LAB_CONSOLE_DEFAULT_HEIGHT)
  const [collapsed, setCollapsed] = useState(false)
  const drag = useRef<{ startY: number; startHeight: number } | null>(null)

  function onDragStart(e: PointerEvent<HTMLDivElement>) {
    drag.current = { startY: e.clientY, startHeight: height }
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  function onDragMove(e: PointerEvent<HTMLDivElement>) {
    if (!drag.current) return
    const delta = drag.current.startY - e.clientY
    const maxHeight = window.innerHeight * MAX_HEIGHT_RATIO
    const next = Math.min(maxHeight, Math.max(MIN_HEIGHT, drag.current.startHeight + delta))
    setHeight(next)
    onHeightChange?.(next)
  }

  function onDragEnd() {
    drag.current = null
  }

  function toggleCollapsed() {
    setCollapsed((c) => {
      const next = !c
      onHeightChange?.(next ? LAB_CONSOLE_COLLAPSED_HEIGHT : height)
      return next
    })
  }

  // No document during SSR — this only ever mounts client-side once a lab
  // session is running, so the null-then-portal swap on hydration is safe.
  if (typeof document === "undefined") return null

  return createPortal(
    <div
      className="fixed inset-x-0 bottom-0 z-sticky hidden flex-col border-t border-border bg-card shadow-raised md:flex h-[var(--lab-console-h)]"
      style={{ "--lab-console-h": `${collapsed ? LAB_CONSOLE_COLLAPSED_HEIGHT : height}px` } as React.CSSProperties}
    >
      {!collapsed && (
        <div
          aria-label="Resize console"
          className="h-1.5 w-full shrink-0 cursor-ns-resize touch-none bg-transparent transition-colors duration-fast hover:bg-primary/30"
          role="separator"
          onPointerDown={onDragStart}
          onPointerMove={onDragMove}
          onPointerUp={onDragEnd}
        />
      )}
      <div className="flex h-11 shrink-0 items-center gap-2 px-3">
        <TerminalSquare aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
        <span className="text-xs font-medium text-foreground">{title}</span>
        <Button
          aria-label={collapsed ? "Expand console" : "Collapse console"}
          className="touch-target ml-auto"
          size="icon"
          variant="ghost"
          onClick={toggleCollapsed}
        >
          {collapsed ? (
            <ChevronUp aria-hidden className="h-3.5 w-3.5" />
          ) : (
            <ChevronDown aria-hidden className="h-3.5 w-3.5" />
          )}
        </Button>
      </div>
      <div className={cn("min-h-0 flex-1", collapsed && "hidden")}>{children}</div>
    </div>,
    document.body,
  )
}
