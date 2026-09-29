"use client"

import { useState } from "react"
import { AlertCircle, ExternalLink, MonitorSmartphone, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { IconMessage } from "@/components/shared/icon-message"
import { useLabIde } from "@/hooks/use-lab-ide"

interface DebugIdeFrameProps {
  sessionId: string
  idePort: number
}

/**
 * The browser IDE (openvscode-server) served through labproxy like a preview
 * port. The iframe src is fixed after the first token mint so VS Code never
 * reloads; a hidden iframe renews the origin cookie every 4 minutes.
 */
export function DebugIdeFrame({ sessionId, idePort }: DebugIdeFrameProps) {
  const { ideUrl, refreshUrl, popOutUrl, hasError } = useLabIde(sessionId, idePort)
  const [isLoaded, setIsLoaded] = useState(false)
  const [reloadKey, setReloadKey] = useState(0)

  return (
    <div className="flex h-full min-h-0 flex-col">
      <IconMessage className="bg-muted/50 lg:hidden" icon={MonitorSmartphone} variant="strip">
        The IDE works best on a larger screen. Pop it out into its own tab for more room.
      </IconMessage>
      <div className="flex shrink-0 items-center gap-2 border-b border-border bg-card px-3 py-1.5">
        <span className="truncate text-xs text-muted-foreground">Browser IDE</span>
        <div className="ml-auto flex items-center gap-1">
          <Button
            aria-label="Reload IDE"
            className="touch-target text-muted-foreground hover:text-foreground"
            size="sm"
            variant="ghost"
            onClick={() => {
              setIsLoaded(false)
              setReloadKey((k) => k + 1)
            }}
          >
            <RefreshCw aria-hidden className="h-3.5 w-3.5" />
          </Button>
          {popOutUrl && (
            <Button asChild className="touch-target gap-1.5" size="sm" variant="ghost">
              {/* External labproxy origin — next/link is for internal routes. */}
              <a href={popOutUrl} rel="noreferrer" target="_blank">
                <ExternalLink aria-hidden className="h-3.5 w-3.5" />
                Pop out IDE
              </a>
            </Button>
          )}
        </div>
      </div>

      <div className="relative min-h-0 flex-1 bg-background">
        {hasError ? (
          <div className="empty-state h-full">
            <AlertCircle aria-hidden className="h-6 w-6 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">
              Could not open the IDE. The session may have expired.
            </p>
          </div>
        ) : (
          <>
            {ideUrl && (
              <iframe
                allow="clipboard-read; clipboard-write"
                className="h-full w-full border-0 bg-background"
                key={reloadKey}
                sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-modals allow-downloads"
                src={reloadKey === 0 ? ideUrl : (popOutUrl ?? ideUrl)}
                title="Browser IDE"
                onLoad={() => setIsLoaded(true)}
              />
            )}
            {!isLoaded && (
              <div
                aria-live="polite"
                className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-background"
                role="status"
              >
                <Skeleton className="h-2 w-40" />
                <p className="text-sm text-muted-foreground">Starting your IDE…</p>
              </div>
            )}
          </>
        )}
      </div>

      {refreshUrl && (
        // Unsandboxed on purpose: a 204 from our own labproxy whose only job is
        // to re-set the IDE origin's cookie via the preview-auth redirect.
        <iframe
          aria-hidden
          className="hidden"
          src={refreshUrl}
          tabIndex={-1}
          title="IDE session refresh"
        />
      )}
    </div>
  )
}
