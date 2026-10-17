// Container seconds -> compute hours with one decimal (dashboard tile).
export function containerHours(seconds: number): string {
  return (Math.max(0, seconds) / 3600).toFixed(1);
}
