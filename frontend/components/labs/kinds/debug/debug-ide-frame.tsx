"use client"

import { useState } from "react"
import { AlertCircle, MonitorSmartphone } from "lucide-react"
import { Skeleton } from "@/components/ui/skeleton"
import { IconMessage } from "@/components/shared/icon-message"
import type { useLabIde } from "@/hooks/use-lab-ide"

interface DebugIdeFrameProps {
  ide: ReturnType<typeof useLabIde>
  /** After a manual reload the iframe uses the fresh-token URL. */
  reloaded: boolean
}

/**
 * The browser IDE (openvscode-server) served through labproxy like a preview
 * port. The iframe src is fixed after the first token mint so VS Code never
 * reloads on its own; a hidden iframe renews the origin cookie every 4 minutes.
 * The parent remounts this (key) to reload.
 */
export function DebugIdeFrame({ ide, reloaded }: DebugIdeFrameProps) {
  const { ideUrl, refreshUrl, popOutUrl, hasError } = ide
  const [isLoaded, setIsLoaded] = useState(false)

  return (
    <div className="flex h-full min-h-0 flex-col">
      <IconMessage className="bg-muted/50 lg:hidden" icon={MonitorSmartphone} variant="strip">
        The IDE works best on a larger screen. Pop it out into its own tab for more room.
      </IconMessage>

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
                sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-modals allow-downloads"
                src={reloaded ? (popOutUrl ?? ideUrl) : ideUrl}
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
