"use client"

import { useRef, useState, useCallback, useEffect } from "react"
import type { Terminal as XTerm } from "@xterm/xterm"
import type { FitAddon as XFitAddon } from "@xterm/addon-fit"
import { mintWSTokenAction } from "@/app/(app)/labs/[labId]/actions"

interface UseLabTerminalOptions {
  containerRef: React.RefObject<HTMLDivElement | null>
  sessionId: string
}

interface UseLabTerminalReturn {
  isConnected: boolean
  reconnectManually: () => void
}

const RECONNECT_DELAYS = [1000, 2000, 4000, 8000] as const

// ttyd wire protocol (github.com/tsl0922/ttyd): the first WS message from the
// client must be a plain (unprefixed) JSON auth/size frame, or the server
// never spawns the pty. After that, every client->server frame is prefixed
// with a single command byte ('0' = input, '1' = resize) and every
// server->client frame is prefixed with '0' (output), '1' (window title), or
// '2' (preferences) — only '0' frames are terminal data.
const TTYD_INPUT = "0"
const TTYD_RESIZE = "1"
const TTYD_OUTPUT = "0"
const TTYD_OUTPUT_BYTE = TTYD_OUTPUT.charCodeAt(0)

export function useLabTerminal({
  containerRef,
  sessionId,
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

    const scheduleReconnect = () => {
      if (disposed) return
      const delay = RECONNECT_DELAYS[reconnectCountRef.current]
      if (delay === undefined) return
      reconnectCountRef.current += 1
      reconnectTimeout = setTimeout(connectWS, delay)
    }

    // Mints a fresh session token before every connection attempt — the token
    // is short-lived (5 min), so reusing one across reconnects would mean every
    // reconnect after the first 5 minutes fails with "unauthorized" forever.
    const connectWS = () => {
      if (disposed) return

      void mintWSTokenAction(sessionId).then((res) => {
        if (disposed) return
        if (!res.ok || !res.data) {
          scheduleReconnect()
          return
        }

        const proxyUrl =
          process.env.NEXT_PUBLIC_LAB_PROXY_URL ?? "ws://localhost:8081"
        const ws = new WebSocket(
          `${proxyUrl}/ws?session_token=${res.data.session_token}`,
        )
        wsRef.current = ws
        ws.binaryType = "arraybuffer"
        attachWSHandlers(ws)
      })
    }

    const attachWSHandlers = (ws: WebSocket) => {

      ws.onopen = () => {
        if (disposed) {
          ws.close()
          return
        }
        reconnectCountRef.current = 0
        lastReceived.value = Date.now()
        setIsConnected(true)

        // ttyd only spawns the pty after receiving this unprefixed init frame.
        ws.send(
          JSON.stringify({
            AuthToken: "",
            columns: term?.cols ?? 80,
            rows: term?.rows ?? 24,
          }),
        )

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
        if (e.data instanceof ArrayBuffer) {
          const bytes = new Uint8Array(e.data)
          if (bytes.length > 0 && bytes[0] === TTYD_OUTPUT_BYTE) {
            term?.write(bytes.subarray(1))
          }
          return
        }
        const data = e.data as string
        if (data.length > 0 && data[0] === TTYD_OUTPUT) {
          term?.write(data.slice(1))
        }
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
        scheduleReconnect()
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

      // eslint-disable-next-line no-restricted-syntax -- terminal canvas theme requires literal hex; xterm.js does not accept CSS variables in theme config.
      // Values are kept in sync with the --terminal-* tokens in globals.css (bg/chrome/foreground)
      // plus brand accents (amber primary, cyan ai) mapped onto the ANSI yellow/cyan slots.
      term = new Terminal({
        screenReaderMode: true,
        fontFamily: "var(--font-jetbrains-mono)",
        fontSize: 14,
        lineHeight: 2.1,
        letterSpacing: 0.7,
        cursorBlink: true,
        cursorStyle: "bar",
        scrollback: 5000,
        theme: {
          background: "#0a0a0a",
          foreground: "#e5e7eb",
          cursor: "#F59E0B",
          cursorAccent: "#0a0a0a",
          selectionBackground: "#F59E0B40",
          black: "#1c1c1c",
          red: "#f87171",
          green: "#4ade80",
          yellow: "#F59E0B",
          blue: "#60a5fa",
          magenta: "#c084fc",
          cyan: "#22D3EE",
          white: "#e5e7eb",
          brightBlack: "#52525b",
          brightRed: "#fca5a5",
          brightGreen: "#86efac",
          brightYellow: "#fbbf24",
          brightBlue: "#93c5fd",
          brightMagenta: "#d8b4fe",
          brightCyan: "#67e8f9",
          brightWhite: "#f5f5f5",
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
          wsRef.current.send(TTYD_INPUT + data)
        }
      })

      resizeObserver = new ResizeObserver(() => {
        if (resizeDebounce) clearTimeout(resizeDebounce)
        resizeDebounce = setTimeout(() => {
          if (!fit || !term || disposed) return
          fit.fit()
          if (wsRef.current?.readyState === WebSocket.OPEN) {
            wsRef.current.send(
              TTYD_RESIZE + JSON.stringify({ columns: term.cols, rows: term.rows }),
            )
          }
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
  }, [sessionId, containerRef])

  return { isConnected, reconnectManually }
}
