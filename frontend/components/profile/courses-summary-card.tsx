import type { Stats } from '@/lib/profile/types'

interface Props {
  stats: Stats | null
}

export function CoursesSummaryCard({ stats }: Props) {
  return (
    <section aria-label="Courses completed" className="card-base p-6 flex-1">
      <h2 className="text-sm font-semibold text-foreground mb-2">Courses</h2>
      <p className="text-2xl font-bold text-foreground tabular-nums">
        {stats?.courses_completed ?? 0}
      </p>
      <p className="text-xs text-muted-foreground">
        of {stats?.courses_enrolled ?? 0} enrolled completed
      </p>
    </section>
  )
}
