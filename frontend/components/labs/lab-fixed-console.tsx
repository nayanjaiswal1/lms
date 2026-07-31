"use client"

import { useRef, useState, type PointerEvent, type ReactNode } from "react"
import { createPortal } from "react-dom"
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  PanelBottom,
  PanelRight,
  TerminalSquare,
  X,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

export const LAB_CONSOLE_DEFAULT_HEIGHT = 340
export const LAB_CONSOLE_COLLAPSED_HEIGHT = 44

const MIN_SIZE = 220
const MAX_SIZE_RATIO = 0.85

type Position = "bottom" | "right"

interface LabFixedConsoleProps {
  title: string
  children: ReactNode
  onHeightChange?: (px: number) => void
  /**
   * Which edges this panel may dock to, in preference order — the first
   * entry is the initial position. Defaults to both, starting bottom. Pass
   * a single entry to lock the panel there and hide the move-to-X toggle
   * (e.g. LessonCompilerToggle restricts this to ["right"] when
   * FEATURES.LESSON_COMPILER_BOTTOM_DOCK is off for the org).
   */
  positions?: Position[]
  /** Shows a close button in the header when the panel has an owning open/close toggle (e.g. LessonCompilerToggle). Omit for panels that are always mounted, like the main lab workspace console. */
  onClose?: () => void
}

// Google Cloud Shell style: a full-viewport panel pinned to an edge of the
// browser window (bottom by default, or the right side via the dock toggle).
// Rendered via a portal to <body> so it escapes the article/sidebar layout
// instead of being boxed into the page's own scroll column. The free edge is
// drag-resizable; the chevron collapses it to just its header bar.
export function LabFixedConsole({
  title,
  children,
  onHeightChange,
  positions = ["bottom", "right"],
  onClose,
}: LabFixedConsoleProps) {
  const [size, setSize] = useState(LAB_CONSOLE_DEFAULT_HEIGHT)
  const [layout, setLayout] = useState<{ position: Position; collapsed: boolean }>(() => ({
    position: positions[0] ?? "bottom",
    collapsed: false,
  }))
  const drag = useRef<{ start: number; startSize: number } | null>(null)
  const isRight = layout.position === "right"
  const canTogglePosition = positions.length > 1

  function onDragStart(e: PointerEvent<HTMLDivElement>) {
    drag.current = { start: isRight ? e.clientX : e.clientY, startSize: size }
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  function onDragMove(e: PointerEvent<HTMLDivElement>) {
    if (!drag.current) return
    const pointer = isRight ? e.clientX : e.clientY
    const delta = drag.current.start - pointer
    const maxSize = (isRight ? window.innerWidth : window.innerHeight) * MAX_SIZE_RATIO
    const next = Math.min(maxSize, Math.max(MIN_SIZE, drag.current.startSize + delta))
    setSize(next)
    if (!isRight) onHeightChange?.(next)
  }

  function onDragEnd() {
    drag.current = null
  }

  function toggleCollapsed() {
    setLayout((l) => {
      const collapsed = !l.collapsed
      if (l.position === "bottom") onHeightChange?.(collapsed ? LAB_CONSOLE_COLLAPSED_HEIGHT : size)
      return { ...l, collapsed }
    })
  }

  // ponytail: swapping edges keeps the current size number as-is (no
  // separate remembered width/height) — it's immediately draggable again,
  // and a per-axis default isn't worth a third piece of state.
  function togglePosition() {
    if (!canTogglePosition) return
    setLayout((l) => ({ ...l, position: l.position === "bottom" ? "right" : "bottom" }))
  }

  // No document during SSR — this only ever mounts client-side once a lab
  // session is running, so the null-then-portal swap on hydration is safe.
  if (typeof document === "undefined") return null

  // Collapsing always shrinks to a slim bar on whichever edge the panel is
  // docked to (bottom -> short bar, right -> narrow bar). The header can't
  // fit its horizontal title row inside a 44px-wide strip, so the collapsed
  // header drops the title and stacks just the icon buttons vertically.
  const resolvedSize = layout.collapsed ? LAB_CONSOLE_COLLAPSED_HEIGHT : size
  const collapsedRight = layout.collapsed && isRight

  return createPortal(
    <div
      className={cn(
        "fixed z-sticky hidden bg-card shadow-raised md:flex",
        isRight
          ? "inset-y-0 right-0 flex-row border-l border-border w-[var(--lab-console-size)]"
          : "inset-x-0 bottom-0 flex-col border-t border-border h-[var(--lab-console-size)]",
      )}
      style={{ "--lab-console-size": `${resolvedSize}px` } as React.CSSProperties}
    >
      {!layout.collapsed && (
        <div
          aria-label={isRight ? "Resize panel" : "Resize console"}
          className={cn(
            "shrink-0 touch-none bg-transparent transition-colors duration-fast hover:bg-primary/30",
            isRight ? "h-full w-1 cursor-ew-resize" : "h-1 w-full cursor-ns-resize",
          )}
          role="separator"
          onPointerDown={onDragStart}
          onPointerMove={onDragMove}
          onPointerUp={onDragEnd}
        />
      )}
      <div className="flex min-h-0 min-w-0 flex-1 flex-col">
        <div
          className={cn(
            "flex shrink-0 items-center gap-2 px-3",
            collapsedRight ? "h-full w-11 flex-col justify-center px-0 py-3" : "h-11",
          )}
        >
          {!collapsedRight && (
            <>
              <TerminalSquare aria-hidden className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
              <span className="truncate text-xs font-medium text-foreground">{title}</span>
            </>
          )}
          <div
            className={cn(
              "flex shrink-0 items-center gap-1",
              collapsedRight ? "flex-col" : "ml-auto",
            )}
          >
            {canTogglePosition && (
              <Button
                aria-label={isRight ? "Move to bottom" : "Move to right side"}
                className="touch-target"
                size="icon"
                variant="ghost"
                onClick={togglePosition}
              >
                {isRight ? (
                  <PanelBottom aria-hidden className="h-3.5 w-3.5" />
                ) : (
                  <PanelRight aria-hidden className="h-3.5 w-3.5" />
                )}
              </Button>
            )}
            <Button
              aria-label={layout.collapsed ? "Expand panel" : "Collapse panel"}
              className="touch-target"
              size="icon"
              variant="ghost"
              onClick={toggleCollapsed}
            >
              {isRight ? (
                layout.collapsed ? (
                  <ChevronLeft aria-hidden className="h-3.5 w-3.5" />
                ) : (
                  <ChevronRight aria-hidden className="h-3.5 w-3.5" />
                )
              ) : layout.collapsed ? (
                <ChevronUp aria-hidden className="h-3.5 w-3.5" />
              ) : (
                <ChevronDown aria-hidden className="h-3.5 w-3.5" />
              )}
            </Button>
            {onClose && (
              <Button aria-label="Close panel" className="touch-target" size="icon" variant="ghost" onClick={onClose}>
                <X aria-hidden className="h-3.5 w-3.5" />
              </Button>
            )}
          </div>
        </div>
        <div className={cn("min-h-0 flex-1", layout.collapsed && "hidden")}>{children}</div>
      </div>
    </div>,
    document.body,
  )
}
