import { Badge } from "@/components/ui/badge"
import { MissionCard } from "@/components/labs/kinds/debug/mission/mission-card"
import { cn } from "@/lib/utils"
import type { TaskCompletion } from "@/lib/labs"

interface MissionLiveStatusProps {
  resolved: boolean
  passed: number
  total: number
  score: number
  maxScore: number
  completions: TaskCompletion[]
}

/** Numbers from the last real Check — nothing here is estimated. */
export function MissionLiveStatus({
  resolved,
  passed,
  total,
  score,
  maxScore,
  completions,
}: MissionLiveStatusProps) {
  const attempts = completions.reduce((sum, c) => sum + c.attempts, 0)
  const hints = completions.reduce((sum, c) => sum + c.hints_used, 0)
  const rows = [
    { label: "Checks passed", value: `${passed}/${total}`, good: passed === total },
    { label: "Score", value: `${score}/${maxScore}`, good: maxScore > 0 && score === maxScore },
    { label: "Check runs", value: String(attempts), good: false },
    { label: "Hints used", value: String(hints), good: false },
  ]

  return (
    <MissionCard
      aside={
        <Badge variant={resolved ? "secondary" : "destructive"}>
          {resolved ? "Resolved" : "Incident open"}
        </Badge>
      }
      label="Live status"
    >
      <dl className="flex flex-col gap-1 text-xs">
        {rows.map((row) => (
          <div className="flex items-center justify-between gap-2" key={row.label}>
            <dt className="text-muted-foreground">{row.label}</dt>
            <dd className={cn("font-mono font-medium tabular-nums", row.good && "text-success")}>
              {row.value}
            </dd>
          </div>
        ))}
      </dl>
      <p className="text-xs text-muted-foreground">Updates when you run Check.</p>
    </MissionCard>
  )
}
