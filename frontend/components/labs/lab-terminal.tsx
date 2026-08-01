// requires: pnpm add @xterm/xterm @xterm/addon-fit @xterm/addon-web-links
// Import this component via next/dynamic({ ssr: false }) in parent components.

"use client"

import { WifiOff } from "lucide-react"
import { Button } from "@/components/ui/button"
import { LAB_FILE_DRAG_MIME } from "@/lib/labs/files"

// CSS must be imported statically so Next.js bundles it.
// If the package is not yet installed, run: pnpm add @xterm/xterm
import "@xterm/xterm/css/xterm.css"

interface LabTerminalProps {
  containerRef: (node: HTMLDivElement | null) => void
  isConnected: boolean
  /** True once automatic reconnect attempts are exhausted — see useLabTerminal. */
  hasGivenUp?: boolean
  reconnectManually: () => void
  /** Types text into the shell — used to insert a file path dropped from the tree. */
  sendText: (text: string) => void
}

// Presentational only — the WebSocket connection (useLabTerminal) is owned by
// LabContainerWorkspace so its connection status can be shown in that
// component's persistent tab-bar header instead of a second header here.
export function LabTerminal({ containerRef, isConnected, hasGivenUp, reconnectManually, sendText }: LabTerminalProps) {
  return (
    <div
      className="relative h-full bg-terminal"
      onDragOver={(e) => {
        if (e.dataTransfer.types.includes(LAB_FILE_DRAG_MIME)) e.preventDefault()
      }}
      onDrop={(e) => {
        const path = e.dataTransfer.getData(LAB_FILE_DRAG_MIME)
        if (!path) return
        e.preventDefault()
        // VS Code behavior: dropping a file inserts its path at the prompt so
        // the user can run it — it never auto-executes.
        sendText(path.includes(" ") ? `'${path}'` : path)
      }}
    >
      <div className="h-full w-full px-5 py-4">
        <div className="h-full w-full" ref={containerRef} />
      </div>

      {!isConnected && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-terminal/90 backdrop-blur-sm z-raised">
          <WifiOff aria-hidden className="h-8 w-8 text-terminal-muted-foreground" />
          <p className="text-sm font-medium text-terminal-foreground">
            {hasGivenUp ? "Couldn't reconnect" : "Connection lost"}
          </p>
          <p className="text-xs text-terminal-muted-foreground text-center max-w-xs">
            {hasGivenUp
              ? "Automatic reconnect attempts ran out. Try again, or end the session."
              : "The terminal connection was interrupted. Reconnecting automatically…"}
          </p>
          <Button
            aria-label="Reconnect to terminal"
            size="sm"
            variant="outline"
            onClick={reconnectManually}
          >
            Reconnect
          </Button>
        </div>
      )}
    </div>
  )
}
