// requires: pnpm add @xterm/xterm @xterm/addon-fit @xterm/addon-web-links
// Import this component via next/dynamic({ ssr: false }) in parent components.

"use client"

import { useRef } from "react"
import { SquareTerminal, WifiOff } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useLabTerminal } from "@/hooks/use-lab-terminal"
import { cn } from "@/lib/utils"

// CSS must be imported statically so Next.js bundles it.
// If the package is not yet installed, run: pnpm add @xterm/xterm
import "@xterm/xterm/css/xterm.css"

interface LabTerminalProps {
  sessionId: string
}

export function LabTerminal({ sessionId }: LabTerminalProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const { isConnected, reconnectManually } = useLabTerminal({
    containerRef,
    sessionId,
  })

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2.5 border-b border-terminal-border bg-terminal-chrome px-4 py-2.5 shrink-0">
        <div className="flex items-center gap-2" aria-hidden>
          <span className="h-2.5 w-2.5 rounded-full bg-destructive/70" />
          <span className="h-2.5 w-2.5 rounded-full bg-warning/70" />
          <span className="h-2.5 w-2.5 rounded-full bg-success/70" />
        </div>

        <div className="mx-1 h-4 w-px bg-terminal-border shrink-0" aria-hidden />

        <SquareTerminal aria-hidden className="h-3.5 w-3.5 text-terminal-muted-foreground shrink-0" />
        <span className="text-xs font-medium text-terminal-foreground">Terminal</span>

        <div className="ml-auto flex items-center gap-2">
          <span
            aria-hidden
            className={cn(
              "h-1.5 w-1.5 rounded-full",
              isConnected ? "bg-success animate-pulse" : "bg-destructive",
            )}
          />
          <span className="text-xs text-terminal-muted-foreground">
            {isConnected ? "Connected" : "Disconnected"}
          </span>
        </div>
      </div>

      <div className="relative flex-1 min-h-0 bg-terminal">
        <div className="h-full w-full px-5 py-4">
          <div ref={containerRef} className="h-full w-full" />
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
              onClick={reconnectManually}
              variant="outline"
              size="sm"
              aria-label="Reconnect to terminal"
            >
              Reconnect
            </Button>
          </div>
        )}
      </div>
    </div>
  )
}
