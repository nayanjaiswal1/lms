interface ScoreRingProps {
  score: number
  maxScore: number
}

const RADIUS = 42
const CIRCUMFERENCE = 2 * Math.PI * RADIUS

/** Circular score meter; the number in the middle carries the meaning, the arc is a visual echo. */
export function ScoreRing({ score, maxScore }: ScoreRingProps) {
  const fraction = maxScore > 0 ? Math.min(1, Math.max(0, score / maxScore)) : 0

  return (
    <div className="relative h-28 w-28 shrink-0">
      <svg aria-hidden className="h-full w-full -rotate-90" viewBox="0 0 100 100">
        <circle className="stroke-muted" cx="50" cy="50" fill="none" r={RADIUS} strokeWidth="9" />
        <circle
          className="stroke-primary"
          cx="50"
          cy="50"
          fill="none"
          r={RADIUS}
          strokeDasharray={CIRCUMFERENCE}
          strokeDashoffset={CIRCUMFERENCE * (1 - fraction)}
          strokeLinecap="round"
          strokeWidth="9"
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center tabular-nums">
        <span className="text-2xl font-semibold leading-none">{score}</span>
        <span className="text-xs text-muted-foreground">of {maxScore}</span>
      </div>
    </div>
  )
}
