import { Target } from "lucide-react"
import type { Lab, TaskCompletion } from "@/lib/labs"

interface ResultMissedPointsProps {
  tasks: Lab["tasks"]
  completions: Map<string, TaskCompletion>
}

/** Checks that did not pass (optional ones included), with what each one asks for. */
export function ResultMissedPoints({ tasks, completions }: ResultMissedPointsProps) {
  const missed = tasks.filter((t) => t.points > 0 && completions.get(t.task_id)?.status !== "passed")
  if (missed.length === 0) return null

  return (
    <section aria-labelledby="result-missed" className="card-base flex flex-col gap-3 border-l-4 border-l-primary">
      <h2 className="subsection-title inline-flex items-center gap-2" id="result-missed">
        <Target aria-hidden className="h-5 w-5 text-primary" />
        Points you missed
      </h2>
      <ul className="flex flex-col gap-3">
        {missed.map((task) => (
          <li className="min-w-0" key={task.task_id}>
            <p className="text-sm font-medium">
              {task.title}
              <span className="font-normal text-muted-foreground">
                {" "}
                · {task.points} pts{task.is_optional ? " · optional" : ""}
              </span>
            </p>
            {task.description && (
              <p className="mt-0.5 line-clamp-3 max-w-prose text-sm text-muted-foreground">{task.description}</p>
            )}
          </li>
        ))}
      </ul>
    </section>
  )
}
