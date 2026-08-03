// Calendar math shared by every Habit Tracker component. All dates are plain
// "YYYY-MM-DD"/"YYYY-MM" strings computed in UTC so a server render and a
// client render of the same month never disagree by a timezone offset.

export function daysInMonth(month: string): number {
  const [y, m] = month.split("-").map(Number)
  return new Date(Date.UTC(y, m, 0)).getUTCDate()
}

export function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split("-").map(Number)
  const d = new Date(Date.UTC(y, m - 1 + delta, 1))
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`
}

export function monthLabel(month: string): string {
  const [y, m] = month.split("-").map(Number)
  return new Date(Date.UTC(y, m - 1, 1)).toLocaleDateString("en-US", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  })
}

export function dateAt(month: string, day: number): string {
  const [y, m] = month.split("-").map(Number)
  return `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`
}

export function firstOfMonth(month: string): string {
  return `${month}-01`
}

// Sunday=0..Saturday=6 — matches JS Date#getDay() and the backend's Go
// time.Weekday, so a "specific weekdays" habit's stored values line up with
// a given day-of-month with no translation on either side.
export function weekdayOfDay(month: string, day: number): number {
  const [y, m] = month.split("-").map(Number)
  return new Date(Date.UTC(y, m - 1, day)).getUTCDay()
}

// Every Monday whose week overlaps this month — mirrors the backend's
// mondayOfWeek so a week straddling the month boundary lines up with what the
// server actually stored, and renders as 5 or 6 columns depending on the month
// (never hardcode 5 — some months span six Monday-weeks).
export function weekStarts(month: string): string[] {
  const [y, m] = month.split("-").map(Number)
  const monthStart = new Date(Date.UTC(y, m - 1, 1))
  const monthEnd = new Date(Date.UTC(y, m, 0))
  const day = monthStart.getUTCDay() // Sunday = 0
  const offset = (day + 6) % 7
  const cur = new Date(monthStart)
  cur.setUTCDate(monthStart.getUTCDate() - offset)

  const starts: string[] = []
  while (cur <= monthEnd) {
    starts.push(cur.toISOString().slice(0, 10))
    cur.setUTCDate(cur.getUTCDate() + 7)
  }
  return starts
}

// A week's Monday can fall in the previous month and its Sunday in the next
// one (weekStarts intentionally keeps those raw, unclipped dates so they
// match what the backend stored). For drawing a week as a wedge on the day-
// indexed wheel, the span needs clipping to this month's day-of-month range.
export function weekDayRange(weekStart: string, month: string, daysInMonthCount: number): [number, number] {
  const startDay = weekStart.startsWith(`${month}-`) ? Number(weekStart.slice(8, 10)) : 1

  const [wy, wm, wd] = weekStart.split("-").map(Number)
  const end = new Date(Date.UTC(wy, wm - 1, wd + 6))
  const endMonth = `${end.getUTCFullYear()}-${String(end.getUTCMonth() + 1).padStart(2, "0")}`
  const endDay = endMonth === month ? end.getUTCDate() : daysInMonthCount

  return [startDay, endDay]
}
