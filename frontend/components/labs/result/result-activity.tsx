import { ACTIVITY_DISCLOSURE, formatMissionClock, type ActivitySummary } from "@/lib/labs/kinds/debug-mission"

interface ResultActivityProps {
  summary: ActivitySummary
}

/** What was recorded about a mission attempt — the same numbers the org sees. */
export function ResultActivity({ summary }: ResultActivityProps) {
  const stats = [
    { label: "Tab-away events", value: String(summary.tab_away_count) },
    { label: "Time in other tabs", value: formatMissionClock(summary.tab_away_total_ms / 1000) },
    { label: "Large pastes", value: String(summary.paste_count) },
    { label: "Characters pasted", value: String(summary.paste_chars) },
  ]

  return (
    <section aria-labelledby="result-activity" className="flex flex-col gap-2">
      <h2 className="subsection-title" id="result-activity">
        Activity
      </h2>
      <div className="card-base flex flex-col gap-3 p-4">
        <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm sm:grid-cols-4">
          {stats.map((stat) => (
            <div className="flex flex-col" key={stat.label}>
              <dt className="text-xs text-muted-foreground">{stat.label}</dt>
              <dd className="font-mono font-medium tabular-nums">{stat.value}</dd>
            </div>
          ))}
        </dl>
        {summary.files_opened.length > 0 && (
          <div className="flex flex-col gap-1">
            <h3 className="text-xs text-muted-foreground">Files opened</h3>
            <ul className="flex flex-wrap gap-1.5">
              {summary.files_opened.map((file) => (
                <li
                  className="min-w-0 max-w-full truncate rounded-md border border-border bg-muted px-2 py-0.5 font-mono text-xs"
                  key={file.path}
                >
                  {file.path}
                  {file.opens > 1 && <span className="text-muted-foreground"> ×{file.opens}</span>}
                </li>
              ))}
            </ul>
          </div>
        )}
        <p className="border-t border-border pt-2 text-xs text-muted-foreground">{ACTIVITY_DISCLOSURE}</p>
      </div>
    </section>
  )
}
