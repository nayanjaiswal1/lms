import Link from "next/link";
import { TicketDraftPanel } from "@/components/labs/builder/ticket-draft-panel";
import { CandidateCard } from "@/components/labs/builder/candidate-card";
import type { RecipeRef } from "@/components/labs/builder/use-save-spec";
import { canManageBlocks, getCandidates } from "@/lib/labs/builder/server";
import { isTextKind } from "@/lib/labs/builder/text-blocks";
import type { BlockStep as BlockStepConfig } from "@/lib/labs/builder/steps";
import ROUTES from "@/lib/routes";
import type { Candidate } from "@/lib/labs/builder/types";

interface BlockStepProps {
  recipe: RecipeRef;
  step: BlockStepConfig;
  /** Whether the composition is buildable (gates AI ticket drafting). */
  valid: boolean;
}

/** Selected first, then suggested, then compatible, then the greyed-out rest. */
function rank(c: Candidate): number {
  if (c.selected) return 0;
  if (c.suggested) return 1;
  return c.compatible ? 2 : 3;
}

export async function BlockStep({ recipe, step, valid }: BlockStepProps) {
  const [lists, canManage] = await Promise.all([
    Promise.all(step.kinds.map((kind) => getCandidates(recipe.id, kind))),
    canManageBlocks(),
  ]);
  const ticketIds = (lists[step.kinds.indexOf("ticket")] ?? []).filter((c) => c.selected).map((c) => c.version_id);

  return (
    <div className="flex flex-col gap-8">
      {step.kinds.map((kind, i) => {
        const candidates = [...lists[i]].sort((a, b) => rank(a) - rank(b));
        const selectedIds = candidates.filter((c) => c.selected).map((c) => c.version_id);
        const faults = kind === "fault" ? candidates.filter((c) => c.selected).map((c) => ({ key: c.block.block_key, title: c.block.title })) : undefined;
        return (
          <section aria-label={`${kind} blocks`} className="flex flex-col gap-3" key={kind}>
            {step.kinds.length > 1 && <h3 className="text-sm font-semibold capitalize">{kind}</h3>}
            {canManage && isTextKind(kind) && (
              <Link className="w-fit text-sm font-medium text-primary underline-offset-4 hover:underline" href={ROUTES.labBuilderBlockNew(kind)}>
                Write a new {kind} block
              </Link>
            )}
            {candidates.length === 0 ? (
              <p className="text-sm text-muted-foreground">No {kind} blocks are available yet.</p>
            ) : (
              <div className="grid gap-4 md:grid-cols-2">
                {candidates.map((c) => (
                  <CandidateCard
                    candidate={c}
                    key={c.block.id}
                    faults={faults}
                    recipe={recipe}
                    replaces={step.mode === "single" && !c.selected ? selectedIds : []}
                  />
                ))}
              </div>
            )}
          </section>
        );
      })}
      {step.panel === "ticket-draft" && (
        <TicketDraftPanel canDraft={valid} canSave={canManage} recipe={recipe} ticketVersionIds={ticketIds} />
      )}
    </div>
  );
}
