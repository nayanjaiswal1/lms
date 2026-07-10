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
    <section aria-label="Problems solved by difficulty" className="card-base p-6 flex-1">
      <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-center">
        <div className="relative w-full max-w-24 shrink-0">
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
                const dash = Math.max(fraction * CIRCUMFERENCE - 3, 0)
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
                    strokeLinecap="round"
                    strokeWidth="10"
                  >
                    <title>{`${LABEL[d.difficulty]}: ${d.solved}/${d.total} solved`}</title>
                  </circle>
                )
                offset += fraction * CIRCUMFERENCE
                return segment
              })}
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-lg font-bold text-foreground tabular-nums">{solvedTotal}</span>
            <span className="text-[10px] text-muted-foreground">/{totalAvailable}</span>
          </div>
        </div>

        {/* eslint-disable-next-line no-restricted-syntax -- max-w constraint is responsive on sm+ via sm:max-w-[260px] */}
        <div className="w-full max-w-none sm:max-w-[260px] divide-y divide-border">
          {difficulty.map((d) => (
            <div className="flex items-center justify-between gap-3 py-1.5" key={d.difficulty}>
              <span className="flex items-center gap-2 text-xs font-medium text-foreground">
                <span aria-hidden="true" className={`h-1.5 w-1.5 rounded-full shrink-0 ${RING_COLOR[d.difficulty]} bg-current`} />
                {LABEL[d.difficulty]}
              </span>
              <span className="text-xs font-semibold tabular-nums text-muted-foreground">{d.solved}/{d.total}</span>
            </div>
          ))}

          <p className="flex items-center gap-2 pt-1.5 text-xs text-muted-foreground">
            <span aria-hidden="true" className="h-1.5 w-1.5 rounded-full shrink-0 bg-ai" />
            {attempting} Attempting
          </p>
        </div>
      </div>
    </section>
  )
}
