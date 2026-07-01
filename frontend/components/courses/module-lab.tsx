import Link from "next/link";
import { Terminal, Clock, RotateCcw, CheckSquare } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { apiGet } from "@/lib/server/api";
import ROUTES from "@/lib/routes";
import type { Lab } from "@/lib/labs";

interface ModuleLabProps {
  moduleId: string;
  title: string;
}

export async function ModuleLab({ moduleId, title }: ModuleLabProps) {
  let lab: Lab | null = null;
  try {
    lab = await apiGet<Lab>(`/api/modules/${moduleId}/lab`);
  } catch {
    return (
      <div className="empty-state flex-col gap-2 py-16">
        <Terminal aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">Lab not available yet.</p>
      </div>
    );
  }

  const totalPoints = lab.tasks.reduce((s, t) => s + t.points, 0);
  const requiredCount = lab.tasks.filter((t) => !t.is_optional).length;

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-3">
        <div className="flex items-center gap-2 flex-wrap">
          <Badge variant="outline" className="capitalize">{lab.lab_type}</Badge>
          <Badge variant="secondary">
            <Clock aria-hidden className="h-3 w-3 mr-1" />{lab.max_duration} min
          </Badge>
          <Badge variant="secondary">
            <CheckSquare aria-hidden className="h-3 w-3 mr-1" />{lab.tasks.length} tasks
          </Badge>
          {totalPoints > 0 && (
            <Badge variant="secondary">{totalPoints} pts</Badge>
          )}
        </div>
        <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
        {lab.description && (
          <p className="text-muted-foreground leading-relaxed">{lab.description}</p>
        )}
      </header>

      {lab.tasks.length > 0 && (
        <ol className="flex flex-col gap-2">
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
      )}

      <div className="flex flex-col gap-2">
        <p className="text-sm text-muted-foreground">
          {requiredCount} required task{requiredCount !== 1 ? "s" : ""} ·{" "}
          up to {lab.max_resets} reset{lab.max_resets !== 1 ? "s" : ""} ·{" "}
          {lab.max_duration} min time limit
        </p>
        <Button asChild size="lg">
          <Link href={ROUTES.lab(lab.id)}>
            <Terminal aria-hidden className="h-4 w-4 mr-2" />
            Launch Lab
          </Link>
        </Button>
      </div>
    </div>
  );
}
