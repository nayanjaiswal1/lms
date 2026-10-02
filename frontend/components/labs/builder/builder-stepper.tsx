import Link from "next/link";
import { BUILDER_STEPS } from "@/lib/labs/builder/steps";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

interface BuilderStepperProps {
  recipeId: string;
  current: string;
}

/** Wizard step navigation; every step stays reachable (the panel shows what is missing). */
export function BuilderStepper({ recipeId, current }: BuilderStepperProps) {
  return (
    <nav aria-label="Builder steps">
      <ol className="flex flex-wrap gap-2 lg:flex-col lg:gap-1">
        {BUILDER_STEPS.map((s, i) => {
          const active = s.key === current;
          return (
            <li key={s.key}>
              <Link
                aria-current={active ? "step" : undefined}
                className={cn(
                  "touch-target flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors duration-fast",
                  active ? "bg-primary/10 font-semibold text-primary" : "text-muted-foreground hover:bg-muted hover:text-foreground",
                )}
                href={ROUTES.labBuilderRecipe(recipeId, s.key)}
              >
                <span className="font-mono text-xs">{String(i + 1).padStart(2, "0")}</span>
                {s.label}
              </Link>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
