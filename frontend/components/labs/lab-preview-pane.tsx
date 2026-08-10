"use client"

import { RefreshCw, ExternalLink, AlertCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { useLabPreview } from "@/hooks/use-lab-preview"
import { cn } from "@/lib/utils"
import type { LabPort } from "@/lib/labs"

interface LabPreviewPaneProps {
  sessionId: string
  /** Container port the app listens on — shown as context in the toolbar. */
  previewPort: number
  /**
   * Detected listening ports (sandbox workspaces). When present, the toolbar
   * renders a port picker and previewPort is treated as the active selection
   * routed explicitly through labproxy's /preview/{token}/{port}/ path.
   */
  ports?: LabPort[]
  onSelectPort?: (port: number) => void
}

/**
 * CodeSandbox-style live preview of the application running inside the lab
 * container, served through labproxy's authenticated /preview proxy. The
 * app's own dev server hot-reloads on file save; the Refresh button re-mints
 * the short-lived token and reloads the frame.
 */
export function LabPreviewPane({ sessionId, previewPort, ports, onSelectPort }: LabPreviewPaneProps) {
  // Explicit port routing only for sandbox (picker) mode — single-port labs
  // keep the original /preview/{token}/ URL resolved from the lab definition.
  const { previewUrl, refresh, hasError } = useLabPreview(
    sessionId,
    ports ? previewPort : undefined,
  )

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-border bg-card px-3 py-1.5 shrink-0">
        {ports ? (
          <div aria-label="Detected application ports" className="flex items-center gap-1 overflow-x-auto" role="tablist">
            {ports.length === 0 && (
              <span className="text-xs text-muted-foreground whitespace-nowrap">
                No open ports detected yet
              </span>
            )}
            {ports.map(({ port, process_name }) => (
              <button
                aria-selected={port === previewPort}
                className={cn(
                  "rounded-md px-2 py-1 text-xs font-medium whitespace-nowrap touch-target",
                  port === previewPort
                    ? "bg-primary/10 text-primary"
                    : "text-muted-foreground hover:text-foreground",
                )}
                key={port}
                role="tab"
                title={process_name ? `Port ${port} — ${process_name}` : `Port ${port}`}
                type="button"
                onClick={() => onSelectPort?.(port)}
              >
                :{port}
                {process_name && (
                  <span className="ml-1 text-muted-foreground">({process_name})</span>
                )}
              </button>
            ))}
          </div>
        ) : (
          <span className="text-xs text-muted-foreground truncate">
            App preview — port {previewPort}
          </span>
        )}
        <div className="ml-auto flex items-center gap-1">
          <Button
            aria-label="Reload preview"
            className="touch-target text-muted-foreground hover:text-foreground"
            size="sm"
            variant="ghost"
            onClick={refresh}
          >
            <RefreshCw aria-hidden className="h-3.5 w-3.5" />
          </Button>
          {previewUrl && (
            <Button
              asChild
              aria-label="Open preview in a new tab"
              className="touch-target text-muted-foreground hover:text-foreground"
              size="sm"
              variant="ghost"
            >
              {/* External labproxy origin — next/link is for internal routes. */}
              <a href={previewUrl} rel="noreferrer" target="_blank">
                <ExternalLink aria-hidden className="h-3.5 w-3.5" />
              </a>
            </Button>
          )}
        </div>
      </div>

      <div className="relative flex-1 min-h-0 bg-background">
        {hasError ? (
          <div className="empty-state h-full">
            <AlertCircle aria-hidden className="h-6 w-6 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">
              Could not load the preview. The session may have expired.
            </p>
            <Button size="sm" variant="outline" onClick={refresh}>
              Try again
            </Button>
          </div>
        ) : previewUrl && previewPort > 0 ? (
          <iframe
            className="h-full w-full border-0 bg-background"
            sandbox="allow-scripts allow-same-origin allow-forms"
            src={previewUrl}
            title="Running application preview"
          />
        ) : ports && previewPort === 0 ? (
          <div className="empty-state h-full">
            <p className="text-sm text-muted-foreground">
              Start a server in the terminal and its port will appear here.
            </p>
          </div>
        ) : (
          <Skeleton className="h-full w-full rounded-none" />
        )}
      </div>
    </div>
  )
}
