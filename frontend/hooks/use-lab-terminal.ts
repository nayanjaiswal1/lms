"use client"

import { useRef, useState, useCallback, useEffect } from "react"
import type { Terminal as XTerm } from "@xterm/xterm"
import type { FitAddon as XFitAddon } from "@xterm/addon-fit"

interface UseLabTerminalOptions {
  containerRef: React.RefObject<HTMLDivElement | null>
  wsToken: string
  sessionId: string
}

interface UseLabTerminalReturn {
  isConnected: boolean
  reconnectManually: () => void
}

const RECONNECT_DELAYS = [1000, 2000, 4000, 8000] as const

export function useLabTerminal({
  containerRef,
  wsToken,
}: UseLabTerminalOptions): UseLabTerminalReturn {
  const [isConnected, setIsConnected] = useState(false)
  const reconnectFnRef = useRef<(() => void) | null>(null)
  const reconnectCountRef = useRef(0)
  const wsRef = useRef<WebSocket | null>(null)
  const termRef = useRef<XTerm | null>(null)

  const reconnectManually = useCallback(() => {
    reconnectCountRef.current = 0
    reconnectFnRef.current?.()
  }, [])

  useEffect(() => {
    if (!containerRef.current) return

    let disposed = false
    let heartbeatInterval: ReturnType<typeof setInterval> | null = null
    let lastPongCheck: ReturnType<typeof setTimeout> | null = null
    let reconnectTimeout: ReturnType<typeof setTimeout> | null = null
    let resizeDebounce: ReturnType<typeof setTimeout> | null = null
    let resizeObserver: ResizeObserver | null = null
    const lastReceived = { value: Date.now() }

    let term: XTerm | null = null
    let fit: XFitAddon | null = null

    const connectWS = () => {
      if (disposed) return

      const proxyUrl =
        process.env.NEXT_PUBLIC_LAB_PROXY_URL ?? "ws://localhost:8081"
      const ws = new WebSocket(`${proxyUrl}/ws?session_token=${wsToken}`)
      wsRef.current = ws
      ws.binaryType = "arraybuffer"

      ws.onopen = () => {
        if (disposed) {
          ws.close()
          return
        }
        reconnectCountRef.current = 0
        lastReceived.value = Date.now()
        setIsConnected(true)

        heartbeatInterval = setInterval(() => {
          if (ws.readyState !== WebSocket.OPEN) return
          ws.send("\x00")
          if (lastPongCheck) clearTimeout(lastPongCheck)
          lastPongCheck = setTimeout(() => {
            if (Date.now() - lastReceived.value > 20000) ws.close()
          }, 5000)
        }, 15000)
      }

      ws.onmessage = (e: MessageEvent) => {
        lastReceived.value = Date.now()
        const data =
          e.data instanceof ArrayBuffer
            ? new Uint8Array(e.data)
            : (e.data as string)
        term?.write(data)
      }

      ws.onclose = () => {
        setIsConnected(false)
        if (heartbeatInterval) {
          clearInterval(heartbeatInterval)
          heartbeatInterval = null
        }
        if (lastPongCheck) {
          clearTimeout(lastPongCheck)
          lastPongCheck = null
        }
        if (disposed) return

        const delay = RECONNECT_DELAYS[reconnectCountRef.current]
        if (delay === undefined) return
        reconnectCountRef.current += 1
        reconnectTimeout = setTimeout(connectWS, delay)
      }

      ws.onerror = () => {
        ws.close()
      }
    }

    reconnectFnRef.current = () => {
      reconnectCountRef.current = 0
      wsRef.current?.close()
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout)
        reconnectTimeout = null
      }
      connectWS()
    }

    const init = async () => {
      if (!containerRef.current || disposed) return

      const { Terminal } = await import("@xterm/xterm")
      const { FitAddon } = await import("@xterm/addon-fit")
      const { WebLinksAddon } = await import("@xterm/addon-web-links")

      if (disposed || !containerRef.current) return

      // eslint-disable-next-line no-restricted-syntax -- terminal canvas theme requires literal hex; xterm.js does not accept CSS variables in theme config
      term = new Terminal({
        screenReaderMode: true,
        fontFamily: "var(--font-jetbrains-mono)",
        fontSize: 14,
        theme: {
          background: "#0a0a0a",
          foreground: "#e5e7eb",
          cursor: "#F59E0B",
        },
      })

      termRef.current = term
      fit = new FitAddon()
      term.loadAddon(fit)
      term.loadAddon(new WebLinksAddon())
      term.open(containerRef.current)
      fit.fit()

      term.onData((data) => {
        if (wsRef.current?.readyState === WebSocket.OPEN) {
          wsRef.current.send(data)
        }
      })

      resizeObserver = new ResizeObserver(() => {
        if (resizeDebounce) clearTimeout(resizeDebounce)
        resizeDebounce = setTimeout(() => {
          if (!fit || !term || disposed) return
          fit.fit()
          wsRef.current?.send(`\x1b[8;${term.rows};${term.cols}t`)
        }, 150)
      })

      if (containerRef.current) {
        resizeObserver.observe(containerRef.current)
      }

      connectWS()
    }

    void init()

    return () => {
      disposed = true
      reconnectFnRef.current = null
      if (heartbeatInterval) clearInterval(heartbeatInterval)
      if (lastPongCheck) clearTimeout(lastPongCheck)
      if (reconnectTimeout) clearTimeout(reconnectTimeout)
      if (resizeDebounce) clearTimeout(resizeDebounce)
      resizeObserver?.disconnect()
      wsRef.current?.close()
      termRef.current?.dispose()
      termRef.current = null
      setIsConnected(false)
    }
  }, [wsToken, containerRef])

  return { isConnected, reconnectManually }
}
