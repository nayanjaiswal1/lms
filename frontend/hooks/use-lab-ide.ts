"use client"

import { useMemo, useSyncExternalStore } from "react"
import { createIdeTokenStore, type IdeTokens } from "@/lib/labs/ide-token-store"
import { buildLabPreviewUrl } from "@/lib/labs/preview-url"

const SERVER_SNAPSHOT: IdeTokens = { first: null, latest: null, failed: false }

interface UseLabIdeReturn {
  /** IDE iframe src; fixed after the first mint so the IDE never reloads. */
  ideUrl: string | null
  /** Hidden-iframe src that silently renews the IDE origin's cookie (204). */
  refreshUrl: string | null
  /** Fresh-token URL for opening the IDE in its own tab. */
  popOutUrl: string | null
  hasError: boolean
}

// The IDE is served like a preview port, so the cookie renewal reuses the
// preview entry flow: /preview/{fresh token}/{ide_port}/__mf/ok redirects to
// <ide-origin>/__mf/preview-auth?t=…&next=/__mf/ok, which sets the cookie and
// answers 204 without touching VS Code.
export function useLabIde(sessionId: string, idePort: number): UseLabIdeReturn {
  const store = useMemo(() => createIdeTokenStore(sessionId), [sessionId])
  const tokens = useSyncExternalStore(store.subscribe, store.getSnapshot, () => SERVER_SNAPSHOT)

  return {
    ideUrl: tokens.first ? buildLabPreviewUrl(tokens.first, idePort) : null,
    refreshUrl:
      tokens.latest && tokens.latest !== tokens.first
        ? buildLabPreviewUrl(tokens.latest, idePort, "__mf/ok")
        : null,
    popOutUrl: tokens.latest ? buildLabPreviewUrl(tokens.latest, idePort) : null,
    hasError: tokens.failed,
  }
}
