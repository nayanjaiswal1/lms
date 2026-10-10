/** "1h 2m 3s" / "2m 3s" / "3s" between two ISO timestamps. */
export function formatDuration(startedAt: string, completedAt: string): string {
  const ms = new Date(completedAt).getTime() - new Date(startedAt).getTime()
  const totalSeconds = Math.max(0, Math.floor(ms / 1000))
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`
  if (minutes > 0) return `${minutes}m ${seconds}s`
  return `${seconds}s`
}
