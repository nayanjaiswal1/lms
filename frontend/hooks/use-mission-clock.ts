"use client"

import { useEffect, useRef, useSyncExternalStore } from "react"
import { MISSION_AUTO_SUBMIT_LEAD_SECONDS } from "@/lib/labs/kinds/debug-mission"

/** secondsLeft while the client has not measured the clock yet (server render). */
export const MISSION_CLOCK_UNKNOWN = -1

export type MissionPhase = "idle" | "running" | "ending" | "expired"

function subscribe(listener: () => void): () => void {
  const id = setInterval(listener, 1000)
  return () => clearInterval(id)
}

interface UseMissionClockOptions {
  /** Server deadline (session.expires_at); the clock only runs once `active`. */
  expiresAt: string
  active: boolean
  /** Fired once, MISSION_AUTO_SUBMIT_LEAD_SECONDS before the deadline (or at once if already past). */
  onAutoSubmit: () => void
}

/**
 * Countdown to the server deadline plus the one-shot auto-submit. The server
 * only accepts a Check that starts before the deadline, so the submit fires
 * early instead of at 0. The deadline is compared against the real clock in
 * the effect, never against the (hydration-safe, initially unknown) rendered value.
 */
export function useMissionClock({ expiresAt, active, onAutoSubmit }: UseMissionClockOptions) {
  const untilMs = new Date(expiresAt).getTime()
  const secondsLeft = useSyncExternalStore(
    subscribe,
    () => Math.max(0, Math.ceil((untilMs - Date.now()) / 1000)),
    () => MISSION_CLOCK_UNKNOWN,
  )
  const fired = useRef(false)
  const onAutoSubmitRef = useRef(onAutoSubmit)
  onAutoSubmitRef.current = onAutoSubmit

  useEffect(() => {
    if (!active || fired.current) return
    if (untilMs - Date.now() > MISSION_AUTO_SUBMIT_LEAD_SECONDS * 1000) return
    fired.current = true
    onAutoSubmitRef.current()
  }, [active, secondsLeft, untilMs])

  let phase: MissionPhase = "idle"
  if (active && secondsLeft !== MISSION_CLOCK_UNKNOWN) {
    if (secondsLeft <= 0) phase = "expired"
    else if (secondsLeft <= MISSION_AUTO_SUBMIT_LEAD_SECONDS) phase = "ending"
    else phase = "running"
  }

  return { secondsLeft, phase }
}
