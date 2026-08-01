"use client"

import dynamic from "next/dynamic"
import { Skeleton } from "@/components/ui/skeleton"
import { useLabTerminal } from "@/hooks/use-lab-terminal"

const LabTerminal = dynamic(
  () => import("@/components/labs/lab-terminal").then((m) => m.LabTerminal),
  { ssr: false, loading: () => <Skeleton className="h-full w-full rounded-none" /> },
)

interface SandboxTerminalTabProps {
  sessionId: string
}

/**
 * One sandbox terminal instance. Each mount owns its own WebSocket and
 * short-lived token via `useLabTerminal` (the hook is fully instance-scoped),
 * and ttyd spawns an independent bash per connection — so N mounted tabs are
 * N real shells into the same container. Must stay mounted while hidden or
 * its connection (and shell) dies with it.
 */
export function SandboxTerminalTab({ sessionId }: SandboxTerminalTabProps) {
  const { containerRef, isConnected, hasGivenUp, reconnectManually, sendText } = useLabTerminal({ sessionId })
  return (
    <LabTerminal
      containerRef={containerRef}
      hasGivenUp={hasGivenUp}
      isConnected={isConnected}
      reconnectManually={reconnectManually}
      sendText={sendText}
    />
  )
}
