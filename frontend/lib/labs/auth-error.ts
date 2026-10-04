/** Shared auth-error sniffing for lab server-action failures. */
export function isLabAuthError(msg: string): boolean {
  const lower = msg.toLowerCase()
  return (
    lower.includes("invalid or expired") ||
    lower.includes("unauthorized") ||
    lower.includes("not authenticated") ||
    lower.includes("session expired")
  )
}
