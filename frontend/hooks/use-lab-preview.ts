"use client"

import { useCallback, useEffect, useState } from "react"
import { mintWSTokenAction } from "@/app/(app)/labs/[labId]/actions"

interface UseLabPreviewReturn {
  /** Full labproxy preview URL for the iframe, or null while minting. */
  previewUrl: string | null
  /** Mints a fresh token and reloads the iframe with it. */
  refresh: () => void
  hasError: boolean
}

/**
 * Builds the authenticated live-app preview URL served by labproxy
 * (/preview/{token}/ or /preview/{token}/{port}/ when an explicit container
 * port is given — sandbox multi-port previews). Tokens are the same
 * short-lived session JWTs the terminal uses, so refresh() re-mints rather
 * than reusing — the document request re-sets labproxy's preview cookies,
 * which is what routes the app's absolute-path subresources.
 */
export function useLabPreview(sessionId: string, port?: number): UseLabPreviewReturn {
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [hasError, setHasError] = useState(false)

  const refresh = useCallback(() => {
    setHasError(false)
    void mintWSTokenAction(sessionId).then((res) => {
      if (!res.ok || !res.data) {
        setHasError(true)
        return
      }
      const wsUrl = process.env.NEXT_PUBLIC_LAB_PROXY_URL ?? "ws://localhost:8081"
      const httpUrl = wsUrl.replace(/^ws/, "http")
      const portSegment = port && port > 0 ? `${port}/` : ""
      setPreviewUrl(`${httpUrl}/preview/${res.data.session_token}/${portSegment}`)
    })
  }, [sessionId, port])

  useEffect(() => {
    refresh()
  }, [refresh])

  return { previewUrl, refresh, hasError }
}
