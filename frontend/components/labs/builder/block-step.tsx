import { CandidateCard } from "@/components/labs/builder/candidate-card";
import type { RecipeRef } from "@/components/labs/builder/use-save-spec";
import { getCandidates } from "@/lib/labs/builder/server";
import type { BlockStep as BlockStepConfig } from "@/lib/labs/builder/steps";
import type { Candidate } from "@/lib/labs/builder/types";

interface BlockStepProps {
  recipe: RecipeRef;
  step: BlockStepConfig;
}

/** Selected first, then suggested, then compatible, then the greyed-out rest. */
function rank(c: Candidate): number {
  if (c.selected) return 0;
  if (c.suggested) return 1;
  return c.compatible ? 2 : 3;
}

export async function BlockStep({ recipe, step }: BlockStepProps) {
  const lists = await Promise.all(step.kinds.map((kind) => getCandidates(recipe.id, kind)));

  return (
    <div className="flex flex-col gap-8">
      {step.kinds.map((kind, i) => {
        const candidates = [...lists[i]].sort((a, b) => rank(a) - rank(b));
        const selectedIds = candidates.filter((c) => c.selected).map((c) => c.version_id);
        return (
          <section aria-label={`${kind} blocks`} className="flex flex-col gap-3" key={kind}>
            {step.kinds.length > 1 && <h3 className="text-sm font-semibold capitalize">{kind}</h3>}
            {candidates.length === 0 ? (
              <p className="text-sm text-muted-foreground">No {kind} blocks are available yet.</p>
            ) : (
              <div className="grid gap-4 md:grid-cols-2">
                {candidates.map((c) => (
                  <CandidateCard
                    candidate={c}
                    key={c.block.id}
                    recipe={recipe}
                    replaces={step.mode === "single" && !c.selected ? selectedIds : []}
                  />
                ))}
              </div>
            )}
          </section>
        );
      })}
    </div>
  );
}
