"use client"

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react"
import type { ActiveLabSession, SessionStatus } from "@/lib/labs"

interface LabProvisioningContextValue {
  session: ActiveLabSession | null
  track: (session: ActiveLabSession) => void
  updateStatus: (sessionId: string, status: SessionStatus) => void
  clear: (sessionId: string) => void
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

  const track = useCallback((next: ActiveLabSession) => setSession(next), [])

  const updateStatus = useCallback((sessionId: string, status: SessionStatus) => {
    setSession((prev) => (prev && prev.session_id === sessionId ? { ...prev, status } : prev))
  }, [])

  const clear = useCallback((sessionId: string) => {
    setSession((prev) => (prev && prev.session_id === sessionId ? null : prev))
  }, [])

  const value = useMemo(
    () => ({ session, track, updateStatus, clear }),
    [session, track, updateStatus, clear],
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
