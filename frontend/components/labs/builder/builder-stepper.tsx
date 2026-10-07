import Link from "next/link";
import { Check } from "lucide-react";
import { BUILDER_STEPS } from "@/lib/labs/builder/steps";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

interface BuilderStepperProps {
  recipeId: string;
  current: string;
  /** Keys of steps that already hold what they need. */
  done: ReadonlySet<string>;
}

/** Horizontal wizard navigation, scrollable on small screens; every step stays reachable. */
export function BuilderStepper({ recipeId, current, done }: BuilderStepperProps) {
  return (
    <nav aria-label="Builder steps" className="table-responsive border-b border-border">
      <ol className="flex min-w-max gap-1">
        {BUILDER_STEPS.map((s, i) => {
          const active = s.key === current;
          const complete = done.has(s.key);
          return (
            <li key={s.key}>
              <Link
                aria-current={active ? "step" : undefined}
                className={cn(
                  "touch-target flex items-center gap-2 whitespace-nowrap border-b-2 px-3 text-sm transition-colors duration-fast",
                  active
                    ? "border-primary font-semibold text-primary"
                    : "border-transparent text-muted-foreground hover:text-foreground",
                )}
                href={ROUTES.labBuilderRecipe(recipeId, s.key)}
              >
                <span
                  className={cn(
                    "flex h-5 w-5 items-center justify-center rounded-full text-xs",
                    complete ? "bg-success/10 text-success" : "bg-muted",
                  )}
                >
                  {complete ? <Check aria-label="Done" className="h-3 w-3" /> : i + 1}
                </span>
                {s.label}
              </Link>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
