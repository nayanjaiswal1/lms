"use client"

import { ExternalLink, MonitorSmartphone, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { DebugIdeUnavailable } from "@/components/labs/kinds/debug/debug-ide-unavailable"
import { Skeleton } from "@/components/ui/skeleton"
import { IconMessage } from "@/components/shared/icon-message"
import { useIdeFrameLoad } from "@/hooks/use-ide-frame-load"
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
  const { ideUrl, refreshUrl, popOutUrl, hasError, popOut } = useLabIde(sessionId, idePort)
  const { isLoaded, reloadKey, gaveUp, onLoad, reload: reloadIde } = useIdeFrameLoad(!!ideUrl)

  return (
    <div className="flex h-full min-h-0 flex-col">
      <IconMessage className="bg-muted/50 md:hidden" icon={MonitorSmartphone} variant="strip">
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
            onClick={reloadIde}
          >
            <RefreshCw aria-hidden className="h-3.5 w-3.5" />
          </Button>
          {popOutUrl && (
            <Button asChild className="touch-target gap-1.5" size="sm" variant="ghost">
              {/* External labproxy origin — next/link is for internal routes. */}
              <a
                href={popOutUrl}
                rel="noreferrer"
                target="_blank"
                onClick={(e) => {
                  e.preventDefault()
                  void popOut()
                }}
              >
                <ExternalLink aria-hidden className="h-3.5 w-3.5" />
                Pop out IDE
              </a>
            </Button>
          )}
        </div>
      </div>

      <div className="relative min-h-0 flex-1 bg-background">
        {hasError ? (
          <DebugIdeUnavailable sessionId={sessionId} />
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
                onLoad={onLoad}
              />
            )}
            {!isLoaded && (
              <div
                aria-live="polite"
                className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-background"
                role="status"
              >
                {gaveUp ? (
                  <>
                    <p className="text-sm text-muted-foreground">
                      The IDE is taking too long to start.
                    </p>
                    <Button size="sm" variant="outline" onClick={reloadIde}>
                      Reload IDE
                    </Button>
                  </>
                ) : (
                  <>
                    <Skeleton className="h-2 w-40" />
                    <p className="text-sm text-muted-foreground">Starting your IDE…</p>
                  </>
                )}
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
