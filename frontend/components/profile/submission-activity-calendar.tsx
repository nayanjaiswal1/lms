import { cn } from '@/lib/utils'
import type { CalendarDay } from '@/lib/profile/types'

interface Props {
  calendar: CalendarDay[]
  totalSubmissions: number
  activeDays: number
  maxStreak: number
}

interface Cell {
  date: string
  count: number
}

const MS_PER_DAY = 24 * 60 * 60 * 1000
const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const BUCKET_CLASS = ['bg-muted', 'bg-primary/25', 'bg-primary/45', 'bg-primary/70', 'bg-primary']

function bucketOf(count: number): number {
  if (count <= 0) return 0
  if (count === 1) return 1
  if (count <= 3) return 2
  if (count <= 6) return 3
  return 4
}

function buildWeeks(calendar: CalendarDay[]): (Cell | null)[][] {
  const counts = new Map(calendar.map((d) => [d.date, d.count]))

  const end = new Date()
  end.setHours(0, 0, 0, 0)
  const start = new Date(end.getTime() - 364 * MS_PER_DAY)
  const gridStart = new Date(start.getTime() - start.getDay() * MS_PER_DAY)

  const weeks: (Cell | null)[][] = []
  let cursor = new Date(gridStart)
  for (;;) {
    const week: (Cell | null)[] = []
    for (let day = 0; day < 7; day++) {
      if (cursor > end) {
        week.push(null)
      } else {
        const iso = cursor.toISOString().slice(0, 10)
        week.push({ date: iso, count: counts.get(iso) ?? 0 })
      }
      cursor = new Date(cursor.getTime() + MS_PER_DAY)
    }
    weeks.push(week)
    if (cursor > end) break
  }
  return weeks
}

function monthLabelForWeek(weeks: (Cell | null)[][], index: number, lastMonth: { value: number }): string | null {
  const cellsInWeek = weeks[index].filter((c): c is Cell => c !== null)
  if (cellsInWeek.length === 0) return null
  // Use the week's last day (not first) to decide its month: the grid's
  // leading week is padded backward to the previous Sunday, so it can span
  // a month boundary — labeling by the first day would emit two labels one
  // column apart (e.g. "Jun" then "Jul"), which visually overlap and merge.
  const lastCell = cellsInWeek[cellsInWeek.length - 1]
  const month = new Date(lastCell.date).getMonth()
  if (month === lastMonth.value) return null
  lastMonth.value = month
  return MONTH_LABELS[month]
}

export function SubmissionActivityCalendar({ calendar, totalSubmissions, activeDays, maxStreak }: Props) {
  const weeks = buildWeeks(calendar)
  const lastMonth = { value: -1 }
  const labels = weeks.map((_, i) => monthLabelForWeek(weeks, i, lastMonth))

  return (
    <section aria-label="Submission activity" className="card-base p-6">
      <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 mb-4">
        <h2 className="text-sm font-medium text-foreground">
          <span className="font-bold">{totalSubmissions}</span> submissions in the past year
        </h2>
        <div className="flex gap-4 text-xs text-muted-foreground">
          <span>Total active days: <span className="font-semibold text-foreground">{activeDays}</span></span>
          <span>Max streak: <span className="font-semibold text-foreground">{maxStreak}</span></span>
        </div>
      </div>

      <div className="overflow-x-auto">
        <div className="inline-flex flex-col gap-1 min-w-full">
          <div className="flex gap-1">
            {weeks.map((_, wi) => (
              <div className="relative h-3 w-2.5 shrink-0" key={wi}>
                {labels[wi] && (
                  <span className="absolute left-0 top-0 text-xs leading-none text-muted-foreground whitespace-nowrap">
                    {labels[wi]}
                  </span>
                )}
              </div>
            ))}
          </div>

          <div className="flex gap-1">
            {weeks.map((week, wi) => (
              <div className="flex flex-col gap-1" key={wi}>
                {week.map((cell, di) => (
                  <div
                    aria-hidden={!cell}
                    aria-label={cell ? `${cell.count} submissions on ${cell.date}` : undefined}
                    className={cn(
                      'h-2.5 w-2.5 rounded-sm',
                      cell ? BUCKET_CLASS[bucketOf(cell.count)] : 'bg-transparent',
                    )}
                    key={di}
                    title={cell ? `${cell.date}: ${cell.count} submission${cell.count === 1 ? '' : 's'}` : undefined}
                  />
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
