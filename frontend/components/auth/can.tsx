"use client"

import {
  useHasPermission,
  useHasAnyPermission,
  useHasAllPermissions,
} from "@/lib/auth/permissions"

interface CanProps {
  permission?: string
  anyOf?: string[]
  allOf?: string[]
  children: React.ReactNode
  fallback?: React.ReactNode
}

export function Can({
  permission,
  anyOf,
  allOf,
  children,
  fallback = null,
}: CanProps): React.ReactElement | null {
  const hasOne = useHasPermission(permission ?? "")
  const hasAny = useHasAnyPermission(anyOf ?? [])
  const hasAll = useHasAllPermissions(allOf ?? [])

  let allowed = true

  if (permission !== undefined) allowed = hasOne
  else if (anyOf !== undefined) allowed = hasAny
  else if (allOf !== undefined) allowed = hasAll

  return allowed
    ? (children as React.ReactElement)
    : (fallback as React.ReactElement | null)
}
