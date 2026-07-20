"use client"

import type { ReactNode } from "react"
import { Plus, X, TerminalSquare, FlaskConical } from "lucide-react"
import { cn } from "@/lib/utils"
import { SandboxTerminalTab } from "@/components/labs/sandbox-terminal-tab"

// ponytail: cap 4 terminals — each is a full bash + WebSocket into a
// 1-CPU/512MB container; more is a resource sink with no user demand.
export const MAX_SANDBOX_TERMINALS = 4

interface SandboxTerminalPanelProps {
  sessionId: string
  /** Stable ids of open terminals; each id keeps one mounted WS/shell. */
  terminalIds: number[]
  /** Active bottom-panel tab: a terminal id, or "tests". */
  activeTab: number | "tests"
  /** Rendered inside the Tests tab (run output / submit results). */
  testsContent: ReactNode
  /** Hide the Tests tab entirely (playground labs — nothing to grade). */
  showTests: boolean
  onSelectTab: (tab: number | "tests") => void
  onAddTerminal: () => void
  onCloseTerminal: (id: number) => void
}

/**
 * VS Code-style bottom panel: terminal tabs plus an optional Tests tab. All
 * terminals stay mounted — inactive ones are hidden with `invisible`, never
 * unmounted, because unmounting tears down that tab's WebSocket and shell.
 */
export function SandboxTerminalPanel({
  sessionId,
  terminalIds,
  activeTab,
  testsContent,
  showTests,
  onSelectTab,
  onAddTerminal,
  onCloseTerminal,
}: SandboxTerminalPanelProps) {
  return (
    <div className="flex h-full flex-col">
      <div
        aria-label="Sandbox panel tabs"
        className="flex items-center gap-1 border-b border-border bg-card px-2 shrink-0 overflow-x-auto"
        role="tablist"
      >
        {terminalIds.map((id, index) => (
          <div
            className={cn(
              "flex items-center border-b-2 -mb-px",
              activeTab === id ? "border-primary" : "border-transparent",
            )}
            key={id}
          >
            <button
              aria-selected={activeTab === id}
              className={cn(
                // Compact tabs: desktop-only surface, no 44px touch-target here.
                "flex items-center gap-1.5 pl-3 pr-1 py-1 text-xs font-medium",
                activeTab === id ? "text-primary" : "text-muted-foreground hover:text-foreground",
              )}
              role="tab"
              type="button"
              onClick={() => onSelectTab(id)}
            >
              <TerminalSquare aria-hidden className="h-3.5 w-3.5" />
              Terminal {index + 1}
            </button>
            {terminalIds.length > 1 && (
              <button
                aria-label={`Close terminal ${index + 1}`}
                className="p-1 text-muted-foreground hover:text-foreground"
                type="button"
                onClick={() => onCloseTerminal(id)}
              >
                <X aria-hidden className="h-3 w-3" />
              </button>
            )}
          </div>
        ))}

        {terminalIds.length < MAX_SANDBOX_TERMINALS && (
          <button
            aria-label="Open a new terminal"
            className="p-1.5 text-muted-foreground hover:text-foreground"
            type="button"
            onClick={onAddTerminal}
          >
            <Plus aria-hidden className="h-3.5 w-3.5" />
          </button>
        )}

        {showTests && (
          <button
            aria-selected={activeTab === "tests"}
            className={cn(
              "ml-auto flex items-center gap-1.5 px-3 py-1 text-xs font-medium border-b-2 -mb-px",
              activeTab === "tests"
                ? "border-primary text-primary"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
            role="tab"
            type="button"
            onClick={() => onSelectTab("tests")}
          >
            <FlaskConical aria-hidden className="h-3.5 w-3.5" />
            Tests
          </button>
        )}
      </div>

      <div className="flex-1 min-h-0 relative">
        {terminalIds.map((id) => (
          <div
            className={cn(
              "absolute inset-0",
              activeTab !== id && "invisible pointer-events-none",
            )}
            key={id}
          >
            <SandboxTerminalTab sessionId={sessionId} />
          </div>
        ))}
        {showTests && (
          <div
            className={cn(
              "absolute inset-0 overflow-auto bg-background",
              activeTab !== "tests" && "invisible pointer-events-none",
            )}
          >
            {testsContent}
          </div>
        )}
      </div>
    </div>
  )
}
