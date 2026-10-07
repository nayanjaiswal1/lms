/** A lab server action failed because the session is gone (HTTP 401), not because of the lab. */
export function isLabAuthError(res: { status?: number }): boolean {
  return res.status === 401
}
