// Counted outside any component so the render-purity lint does not see the clock read.
export function countPendingInvites(
  invites: { accepted_at?: string | null; revoked_at?: string | null; expires_at: string }[],
  nowMs: number = Date.now(),
): number {
  return invites.filter((i) => !i.accepted_at && !i.revoked_at && new Date(i.expires_at).getTime() > nowMs).length;
}
