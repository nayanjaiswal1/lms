"use client"

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react"
import type { ActiveLabSession, SessionStatus } from "@/lib/labs"

interface LabProvisioningContextValue {
  session: ActiveLabSession | null
  track: (session: ActiveLabSession) => void
  updateStatus: (sessionId: string, status: SessionStatus) => void
  clear: (sessionId: string) => void
  // currentPageLabId is the lab_id of whatever lesson-embedded lab is
  // mounted on the page right now (LessonLabProvider registers/unregisters
  // it on mount/unmount) — null on every page without one. Lets
  // LabProvisioningWatcher tell "this page owns the provisioning session I'm
  // tracking, its own inline UI has it covered" apart from "I'm just on some
  // course learn page that happens to have a different lab embedded,"
  // which a pathname-shape check alone can't distinguish.
  currentPageLabId: string | null
  registerCurrentPageLab: (labId: string) => void
  unregisterCurrentPageLab: (labId: string) => void
}

const LabProvisioningContext = createContext<LabProvisioningContextValue | null>(null)

interface LabProvisioningProviderProps {
  children: ReactNode
  initialSession: ActiveLabSession | null
}

// Mounted once in the root layout, seeded with the user's active lab session
// (if any) fetched server-side in getActiveLabSession() — so a running lab
// survives a page refresh or a fresh login instead of only living in
// client-side state. The backend allows only one active session per user
// (see labs.Service.StartSession), so this holds at most one entry.
export function LabProvisioningProvider({ children, initialSession }: LabProvisioningProviderProps) {
  const [session, setSession] = useState<ActiveLabSession | null>(initialSession)
  const [currentPageLabId, setCurrentPageLabId] = useState<string | null>(null)

  const track = useCallback((next: ActiveLabSession) => setSession(next), [])

  const updateStatus = useCallback((sessionId: string, status: SessionStatus) => {
    setSession((prev) => (prev && prev.session_id === sessionId ? { ...prev, status } : prev))
  }, [])

  const clear = useCallback((sessionId: string) => {
    setSession((prev) => (prev && prev.session_id === sessionId ? null : prev))
  }, [])

  const registerCurrentPageLab = useCallback((labId: string) => setCurrentPageLabId(labId), [])

  const unregisterCurrentPageLab = useCallback((labId: string) => {
    setCurrentPageLabId((prev) => (prev === labId ? null : prev))
  }, [])

  const value = useMemo(
    () => ({ session, track, updateStatus, clear, currentPageLabId, registerCurrentPageLab, unregisterCurrentPageLab }),
    [session, track, updateStatus, clear, currentPageLabId, registerCurrentPageLab, unregisterCurrentPageLab],
  )

  return (
    <LabProvisioningContext.Provider value={value}>
      {children}
    </LabProvisioningContext.Provider>
  )
}

export function useLabProvisioning() {
  const ctx = useContext(LabProvisioningContext)
  if (!ctx) throw new Error("useLabProvisioning must be used within LabProvisioningProvider")
  return ctx
}
