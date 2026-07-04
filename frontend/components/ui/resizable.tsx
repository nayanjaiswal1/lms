"use client"

import type { ComponentProps } from "react"
import { GripVertical, GripHorizontal } from "lucide-react"
import { Group, Panel, Separator } from "react-resizable-panels"

import { cn } from "@/lib/utils"

function ResizablePanelGroup({
  className,
  ...props
}: ComponentProps<typeof Group>) {
  return (
    <Group
      className={cn("h-full w-full", className)}
      {...props}
    />
  )
}

function ResizablePanel({
  ...props
}: ComponentProps<typeof Panel>) {
  return <Panel {...props} />
}

function ResizableHandle({
  withHandle,
  orientation = "horizontal",
  className,
  ...props
}: ComponentProps<typeof Separator> & {
  withHandle?: boolean
  orientation?: "horizontal" | "vertical"
}) {
  const isVertical = orientation === "vertical"

  return (
    <Separator
      className={cn(
        "relative flex items-center justify-center bg-border transition-colors duration-fast",
        isVertical ? "h-px w-full" : "w-px h-full",
        "hover:bg-primary/40 active:bg-primary",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-primary focus-visible:ring-offset-1",
        className,
      )}
      {...props}
    >
      {withHandle && (
        <div
          className={cn(
            "z-raised flex items-center justify-center rounded-sm border border-border bg-card",
            isVertical ? "h-3 w-8" : "h-8 w-3",
          )}
        >
          {isVertical ? (
            <GripHorizontal className="h-2.5 w-2.5 text-muted-foreground" />
          ) : (
            <GripVertical className="h-2.5 w-2.5 text-muted-foreground" />
          )}
        </div>
      )}
    </Separator>
  )
}

export { ResizablePanelGroup, ResizablePanel, ResizableHandle }
