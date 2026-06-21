"use client"

import { createContext, useContext, useMemo } from "react"

interface PermissionContextValue {
  permissions: ReadonlySet<string>
}

const PermissionContext = createContext<PermissionContextValue | null>(null)

export function PermissionProvider({
  permissions: permissionList,
  children,
}: {
  permissions: string[]
  children: React.ReactNode
}) {
  const permissions = useMemo(
    () => new Set(permissionList) as ReadonlySet<string>,
    [permissionList],
  )

  return (
    <PermissionContext.Provider value={{ permissions }}>
      {children}
    </PermissionContext.Provider>
  )
}

function usePermissionContext(): PermissionContextValue {
  const ctx = useContext(PermissionContext)
  if (!ctx) throw new Error("usePermissions must be used within PermissionProvider")
  return ctx
}

export function usePermissions(): ReadonlySet<string> {
  return usePermissionContext().permissions
}

export function useHasPermission(code: string): boolean {
  return usePermissions().has(code)
}

export function useHasAnyPermission(codes: string[]): boolean {
  const perms = usePermissions()
  return codes.some((c) => perms.has(c))
}

export function useHasAllPermissions(codes: string[]): boolean {
  const perms = usePermissions()
  return codes.every((c) => perms.has(c))
}
