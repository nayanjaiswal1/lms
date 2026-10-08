"use client"

import { useState, type ReactNode } from "react"
import { PanelLeftClose, PanelLeftOpen } from "lucide-react"
import { usePanelRef } from "react-resizable-panels"
import { Button } from "@/components/ui/button"
import {
  ResizableHandle,
  ResizablePanel,
  ResizablePanelGroup,
} from "@/components/ui/resizable"
import { cn } from "@/lib/utils"

interface DebugShellProps {
  /** Optional strip above the split (grader problems). */
  notice?: ReactNode
  /** Ticket / checks / write-up tabs. */
  panel: ReactNode
  /** The IDE + app area; receives the panel toggle so it can sit in its own tab row. */
  children: (panelToggle: ReactNode) => ReactNode
}

/**
 * LeetCode-style split: description panel on the left, IDE on the right, a
 * draggable divider between them and no chrome of its own. The panel
 * collapses on md+ and becomes a bottom sheet below md (closed by default).
 */
export function DebugShell({ notice, panel, children }: DebugShellProps) {
  const panelRef = usePanelRef()
  const [docked, setDocked] = useState(true)
  const [sheetOpen, setSheetOpen] = useState(false)

  const toggle = (
    <Button
      aria-expanded={docked || sheetOpen}
      aria-label="Toggle ticket and checks panel"
      className="touch-target-dense shrink-0 text-muted-foreground hover:text-foreground"
      size="sm"
      variant="ghost"
      onClick={() => {
        setSheetOpen((open) => !open)
        if (panelRef.current?.isCollapsed()) panelRef.current.expand()
        else panelRef.current?.collapse()
      }}
    >
      {docked ? (
        <PanelLeftClose aria-hidden className="h-4 w-4 max-md:hidden" />
      ) : (
        <PanelLeftOpen aria-hidden className="h-4 w-4 max-md:hidden" />
      )}
      <PanelLeftOpen aria-hidden className="h-4 w-4 md:hidden" />
    </Button>
  )

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      {notice}
      <ResizablePanelGroup className="min-h-0 flex-1" orientation="horizontal">
        <ResizablePanel
          collapsible
          className={cn(
            "bg-background",
            "max-md:fixed max-md:inset-x-0 max-md:bottom-0 max-md:z-sticky max-md:max-h-[70dvh] max-md:border-t max-md:border-border max-md:pb-[env(safe-area-inset-bottom)] max-md:shadow-modal",
            sheetOpen ? "max-md:block" : "max-md:hidden",
          )}
          collapsedSize="0%"
          defaultSize="26%"
          id="debug-panel"
          maxSize="45%"
          minSize="18%"
          panelRef={panelRef}
          onResize={(size) => setDocked(size.asPercentage > 0)}
        >
          <div className="flex h-full min-h-0 flex-col">{panel}</div>
        </ResizablePanel>
        <ResizableHandle className="max-md:hidden" />
        <ResizablePanel id="debug-main" minSize="40%">
          {children(toggle)}
        </ResizablePanel>
      </ResizablePanelGroup>
    </div>
  )
}
