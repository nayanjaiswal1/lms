import type { DifficultyCount } from '@/lib/profile/types'

interface Props {
  difficulty: DifficultyCount[]
  solvedTotal: number
  attempting: number
}

const RING_COLOR: Record<DifficultyCount['difficulty'], string> = {
  beginner:     'text-success',
  intermediate: 'text-warning',
  advanced:     'text-destructive',
  expert:       'text-primary',
}

const LABEL: Record<DifficultyCount['difficulty'], string> = {
  beginner:     'Beginner',
  intermediate: 'Intermediate',
  advanced:     'Advanced',
  expert:       'Expert',
}

const RADIUS = 40
const CIRCUMFERENCE = 2 * Math.PI * RADIUS

export function DifficultySolvedChart({ difficulty, solvedTotal, attempting }: Props) {
  const totalAvailable = difficulty.reduce((sum, d) => sum + d.total, 0)
  let offset = 0

  return (
    <section aria-label="Problems solved by difficulty" className="card-base p-6">
      <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-center sm:justify-center sm:gap-8">
        <div className="relative w-full max-w-[160px] shrink-0">
          <svg className="w-full h-auto -rotate-90" viewBox="0 0 100 100">
            <circle
              className="text-muted"
              cx="50"
              cy="50"
              fill="none"
              r={RADIUS}
              stroke="currentColor"
              strokeWidth="10"
            />
            {solvedTotal > 0 &&
              difficulty.map((d) => {
                if (d.solved === 0) return null
                const fraction = d.solved / solvedTotal
                const dash = fraction * CIRCUMFERENCE
                const segment = (
                  <circle
                    className={RING_COLOR[d.difficulty]}
                    cx="50"
                    cy="50"
                    fill="none"
                    key={d.difficulty}
                    r={RADIUS}
                    stroke="currentColor"
                    strokeDasharray={`${dash} ${CIRCUMFERENCE - dash}`}
                    strokeDashoffset={-offset}
                    strokeLinecap="butt"
                    strokeWidth="10"
                  />
                )
                offset += dash
                return segment
              })}
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-2xl font-bold text-foreground tabular-nums">{solvedTotal}</span>
            <span className="text-xs text-muted-foreground">Solved</span>
          </div>
        </div>

        <div className="w-full space-y-2">
          {difficulty.map((d) => (
            <div className="flex items-center justify-between gap-3 text-sm" key={d.difficulty}>
              <span className="flex items-center gap-2 text-muted-foreground">
                <span aria-hidden="true" className={`h-2 w-2 rounded-full bg-current ${RING_COLOR[d.difficulty]}`} />
                {LABEL[d.difficulty]}
              </span>
              <span className="tabular-nums text-foreground">
                {d.solved}
                <span className="text-muted-foreground">/{d.total}</span>
              </span>
            </div>
          ))}
          <div className="flex items-center justify-between gap-3 pt-2 mt-2 border-t border-border text-sm">
            <span className="text-muted-foreground">Attempting</span>
            <span className="tabular-nums text-foreground">{attempting}</span>
          </div>
          {totalAvailable === 0 && (
            <p className="text-xs text-muted-foreground pt-1">No coding questions available yet.</p>
          )}
        </div>
      </div>
    </section>
  )
}
