import { CheckCircle2, Circle } from "lucide-react"
import type { Lab, TaskCompletion } from "@/lib/labs"

interface ResultChecksProps {
  tasks: Lab["tasks"]
  completions: Map<string, TaskCompletion>
}

/** One flat list: status icon, name, points, attempts. */
export function ResultChecks({ tasks, completions }: ResultChecksProps) {
  return (
    <section aria-labelledby="result-checks" className="flex flex-col gap-2">
      <h2 className="subsection-title" id="result-checks">
        Checks
      </h2>
      <ul className="card-base divide-y divide-border overflow-hidden p-0">
        {tasks.map((task) => {
          const completion = completions.get(task.task_id)
          const passed = completion?.status === "passed"
          return (
            <li className="flex items-center gap-3 px-4 py-2.5 text-sm" key={task.task_id}>
              {passed ? (
                <CheckCircle2 aria-label="Passed" className="h-4 w-4 shrink-0 text-success" role="img" />
              ) : (
                <Circle aria-label="Not passed" className="h-4 w-4 shrink-0 text-muted-foreground" role="img" />
              )}
              <span className="min-w-0 flex-1 truncate">
                {task.title}
                {task.is_optional && <span className="text-muted-foreground"> (optional)</span>}
              </span>
              <span className="shrink-0 text-xs text-muted-foreground tabular-nums">
                {task.points} pts
                {completion && completion.attempts > 0 && ` · ${completion.attempts} attempt${completion.attempts !== 1 ? "s" : ""}`}
              </span>
            </li>
          )
        })}
      </ul>
    </section>
  )
}
