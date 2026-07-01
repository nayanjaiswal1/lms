// requires: pnpm add @xterm/xterm @xterm/addon-fit @xterm/addon-web-links
// Import this component via next/dynamic({ ssr: false }) in parent components.

"use client"

import { useRef } from "react"
import { WifiOff } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useLabTerminal } from "@/hooks/use-lab-terminal"

// CSS must be imported statically so Next.js bundles it.
// If the package is not yet installed, run: pnpm add @xterm/xterm
import "@xterm/xterm/css/xterm.css"

interface LabTerminalProps {
  sessionId: string
  wsToken: string
}

export function LabTerminal({ sessionId, wsToken }: LabTerminalProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const { isConnected, reconnectManually } = useLabTerminal({
    containerRef,
    wsToken,
    sessionId,
  })

  return (
    <div className="relative h-full w-full bg-background">
      <div ref={containerRef} className="h-full w-full" />
      {!isConnected && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-background/80 backdrop-blur-sm z-raised">
          <WifiOff
            aria-hidden
            className="h-8 w-8 text-muted-foreground"
          />
          <p className="text-sm font-medium text-foreground">Connection lost</p>
          <p className="text-xs text-muted-foreground text-center max-w-xs">
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
  )
}
