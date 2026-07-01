import type { Metadata } from "next"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { LabLauncher } from "@/components/labs/lab-launcher"
import { apiGet } from "@/lib/server/api"
import type { Lab } from "@/lib/labs"

export const metadata: Metadata = {
  title: "Lab",
  robots: { index: false, follow: false },
}

interface PageProps {
  params: Promise<{ labId: string }>
}

export default async function LabPage({ params }: PageProps) {
  const { labId } = await params
  const lab = await apiGet<Lab>(`/api/labs/${labId}`)

  const totalPoints = lab.tasks.reduce((s, t) => s + t.points, 0)
  const requiredCount = lab.tasks.filter((t) => !t.is_optional).length

  return (
    <main className="page-container-sm py-10 flex flex-col gap-8">
      <header className="flex flex-col gap-3">
        <div className="flex items-center gap-2 flex-wrap">
          <Badge variant="outline" className="capitalize">
            {lab.lab_type}
          </Badge>
          <Badge variant="secondary">{lab.max_duration} min</Badge>
          <Badge variant="secondary">{lab.tasks.length} tasks</Badge>
          {totalPoints > 0 && (
            <Badge variant="secondary">{totalPoints} pts</Badge>
          )}
        </div>
        <h1 className="text-3xl font-bold tracking-tight">{lab.title}</h1>
        {lab.description && (
          <p className="text-muted-foreground leading-relaxed">{lab.description}</p>
        )}
      </header>

      {lab.tasks.length > 0 && (
        <section>
          <h2 className="section-title mb-4">Tasks</h2>
          <ol className="flex flex-col gap-3">
            {lab.tasks.map((task) => (
              <li key={task.task_id} className="card-base p-4 flex items-start gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-semibold text-muted-foreground">
                  {task.position}
                </span>
                <div className="flex flex-col gap-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-medium text-sm">{task.title}</span>
                    {task.is_optional && (
                      <Badge variant="outline" className="text-xs">optional</Badge>
                    )}
                    {task.points > 0 && (
                      <Badge variant="secondary" className="text-xs">{task.points} pts</Badge>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground">{task.description}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>
      )}

      <Separator />

      <div className="flex flex-col gap-2">
        <p className="text-sm text-muted-foreground">
          {requiredCount} required task{requiredCount !== 1 ? "s" : ""} ·{" "}
          up to {lab.max_resets} reset{lab.max_resets !== 1 ? "s" : ""} ·{" "}
          {lab.max_duration} min time limit
        </p>
        <LabLauncher lab={lab} />
      </div>
    </main>
  )
}
