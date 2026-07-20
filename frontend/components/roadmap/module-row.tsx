import Link from "next/link";
import { BookOpen, FlaskConical, Code2, Rocket, FileText, HelpCircle, ExternalLink } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { ModuleProgressToggle } from "@/components/roadmap/module-progress-toggle";
import ROUTES from "@/lib/routes";
import type { RoadmapModule } from "@/lib/server/roadmap";

const MODULE_ICON: Record<RoadmapModule["module_type"], typeof BookOpen> = {
  course: BookOpen,
  lab: FlaskConical,
  dsa_problem: Code2,
  project: Rocket,
  reading: FileText,
  quiz: HelpCircle,
};

function resourceHref(mod: RoadmapModule): string | null {
  if (mod.resource_type === "course" && mod.resource_slug) return ROUTES.course(mod.resource_slug);
  if (mod.resource_type === "lab" && mod.resource_id) return ROUTES.lab(mod.resource_id);
  if (mod.resource_type === "question") return ROUTES.QUESTION_BANK;
  return null;
}

interface ModuleRowProps {
  roadmapId: string;
  mod: RoadmapModule;
}

export function ModuleRow({ roadmapId, mod }: ModuleRowProps) {
  const Icon = MODULE_ICON[mod.module_type] ?? FileText;
  const href = resourceHref(mod);
  const completed = Boolean(mod.completed_at);

  return (
    <li className="flex items-start gap-3 rounded-md border border-border p-3">
      <ModuleProgressToggle
        completed={completed}
        moduleId={mod.id}
        roadmapId={roadmapId}
        title={mod.title}
      />
      <Icon aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" />
      <div className="flex flex-1 flex-col gap-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className={completed ? "text-sm line-through text-muted-foreground" : "text-sm font-medium"}>
            {mod.title}
          </span>
          {mod.estimated_minutes ? (
            <span className="text-xs text-muted-foreground">{mod.estimated_minutes} min</span>
          ) : null}
        </div>
        {mod.description && <p className="text-sm text-muted-foreground">{mod.description}</p>}
        {mod.resource_title && (
          href ? (
            <Link className="ai-badge inline-flex w-fit items-center gap-1 text-xs" href={href}>
              <ExternalLink aria-hidden className="h-3 w-3" />
              {mod.resource_title}
            </Link>
          ) : (
            <Badge className="w-fit" variant="outline">{mod.resource_title}</Badge>
          )
        )}
      </div>
    </li>
  );
}
