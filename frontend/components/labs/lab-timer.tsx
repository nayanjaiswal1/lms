"use client"

import { useState, useRef, useEffect } from "react"
import { Clock } from "lucide-react"
import { cn } from "@/lib/utils"

interface LabTimerProps {
  expiresAt: string
  onExpired?: () => void
}

function formatSeconds(totalSeconds: number): string {
  if (totalSeconds <= 0) return "0:00"
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  const mm = String(minutes).padStart(2, "0")
  const ss = String(seconds).padStart(2, "0")
  if (hours > 0) return `${hours}:${mm}:${ss}`
  return `${mm}:${ss}`
}

export function LabTimer({ expiresAt, onExpired }: LabTimerProps) {
  const [secondsLeft, setSecondsLeft] = useState(() => {
    const ms = new Date(expiresAt).getTime() - Date.now()
    return Math.max(0, Math.floor(ms / 1000))
  })

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const onExpiredRef = useRef(onExpired)
  onExpiredRef.current = onExpired

  useEffect(() => {
    const initialMs = new Date(expiresAt).getTime() - Date.now()
    if (initialMs <= 0) {
      setSecondsLeft(0)
      onExpiredRef.current?.()
      return
    }

    intervalRef.current = setInterval(() => {
      const ms = new Date(expiresAt).getTime() - Date.now()
      const next = Math.max(0, Math.floor(ms / 1000))
      setSecondsLeft(next)
      if (next <= 0) {
        if (intervalRef.current) clearInterval(intervalRef.current)
        onExpiredRef.current?.()
      }
    }, 1000)

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current)
    }
  }, [expiresAt])

  const isWarning = secondsLeft > 0 && secondsLeft <= 600

  return (
    <div
      className={cn(
        "inline-flex items-center gap-1.5 text-sm font-mono font-semibold tabular-nums",
        isWarning ? "text-destructive" : "text-foreground",
      )}
      aria-live="polite"
      aria-label={`Time remaining: ${formatSeconds(secondsLeft)}`}
    >
      <Clock
        aria-hidden
        className={cn(
          "h-4 w-4 shrink-0",
          isWarning ? "text-destructive" : "text-muted-foreground",
        )}
      />
      {formatSeconds(secondsLeft)}
    </div>
  )
}
