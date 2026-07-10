// requires: pnpm add @xterm/xterm @xterm/addon-fit @xterm/addon-web-links
// Import this component via next/dynamic({ ssr: false }) in parent components.

"use client"

import { WifiOff } from "lucide-react"
import { Button } from "@/components/ui/button"

// CSS must be imported statically so Next.js bundles it.
// If the package is not yet installed, run: pnpm add @xterm/xterm
import "@xterm/xterm/css/xterm.css"

interface LabTerminalProps {
  containerRef: (node: HTMLDivElement | null) => void
  isConnected: boolean
  reconnectManually: () => void
}

// Presentational only — the WebSocket connection (useLabTerminal) is owned by
// LabContainerWorkspace so its connection status can be shown in that
// component's persistent tab-bar header instead of a second header here.
export function LabTerminal({ containerRef, isConnected, reconnectManually }: LabTerminalProps) {
  return (
    <div className="relative h-full bg-terminal">
      <div className="h-full w-full px-5 py-4">
        <div className="h-full w-full" ref={containerRef} />
      </div>

      {!isConnected && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-terminal/90 backdrop-blur-sm z-raised">
          <WifiOff aria-hidden className="h-8 w-8 text-terminal-muted-foreground" />
          <p className="text-sm font-medium text-terminal-foreground">Connection lost</p>
          <p className="text-xs text-terminal-muted-foreground text-center max-w-xs">
            The terminal connection was interrupted. You can reconnect or end
            the session.
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
