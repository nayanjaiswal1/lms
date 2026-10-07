"use client";

import { Ban, Lightbulb } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { FaultLinks, type FaultPeer } from "@/components/labs/builder/fault-links";
import { ParamEditor } from "@/components/labs/builder/param-editor";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { paramFields } from "@/lib/labs/builder/params";
import { withBlock, withChain, withoutBlock } from "@/lib/labs/builder/spec";
import type { Candidate } from "@/lib/labs/builder/types";
import { cn } from "@/lib/utils";

interface CandidateCardProps {
  recipe: RecipeRef;
  candidate: Candidate;
  /** Selected blocks this one replaces when added (single-per-kind steps). */
  replaces: string[];
  /** The selected faults of the recipe (fault step only): enables chain and pool controls. */
  faults?: FaultPeer[];
}

export function CandidateCard({ recipe, candidate: c, replaces, faults }: CandidateCardProps) {
  const { save, pending } = useSaveSpec(recipe);
  const fields = paramFields(c.manifest);
  const features = c.manifest?.app?.features ?? [];
  const disabled = !c.compatible && !c.selected;
  const addSpec = () => {
    const spec = withBlock(recipe.spec, c.version_id, replaces);
    return c.chain_after ? withChain(spec, c.version_id, { after: c.chain_after, mode: "masks" }) : spec;
  };

  return (
    <article
      className={cn("card-base flex flex-col gap-2 p-4", c.selected && "border-primary", disabled && "opacity-60")}
    >
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <h3 className="text-sm font-semibold">{c.block.title}</h3>
          <p className="truncate font-mono text-xs text-muted-foreground">
            {c.block.block_key}@{c.manifest?.version ?? c.block.latest_version}
          </p>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {c.suggested && !c.selected && <Badge className="badge-info" variant="outline">Suggested</Badge>}
          {c.block.difficulty && <Badge className="badge-muted" variant="outline">{c.block.difficulty}</Badge>}
          {c.block.category && <Badge className="badge-muted" variant="outline">{c.block.category}</Badge>}
        </div>
      </div>
      {c.block.summary && <p className="text-sm text-muted-foreground">{c.block.summary}</p>}
      {features.length > 0 && (
        <p className="truncate text-xs text-muted-foreground">Features: {features.join(", ")}</p>
      )}

      {c.blockers.map((b) => (
        <p className="flex items-start gap-1.5 text-xs text-destructive" key={b}>
          <Ban aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          {b}
        </p>
      ))}
      {c.chain_after && !c.selected && (
        <p className="flex items-start gap-1.5 text-xs text-muted-foreground">
          <Lightbulb aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Overlaps another fault; added chained after it.
        </p>
      )}
      {c.needs.map((n) => (
        <p className="flex items-start gap-1.5 text-xs text-muted-foreground" key={n}>
          <Lightbulb aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Needs: {n}
        </p>
      ))}

      <div className="flex flex-wrap gap-2">
        {c.selected ? (
          <Button disabled={pending} size="sm" variant="outline" onClick={() => save(withoutBlock(recipe.spec, c.version_id, c.block.block_key))}>
            Remove
          </Button>
        ) : (
          <Button disabled={pending || disabled} size="sm" onClick={() => save(addSpec())}>
            {replaces.length > 0 ? "Use this instead" : c.chain_after ? "Add as chained fault" : "Add"}
          </Button>
        )}
      </div>

      {c.selected && faults && (
        <FaultLinks
          declaredChain={c.manifest?.fault?.chain}
          peers={faults.filter((f) => f.key !== c.block.block_key)}
          recipe={recipe}
          versionId={c.version_id}
        />
      )}

      {c.selected && fields.length > 0 && (
        <details className="border-t border-border pt-2">
          <summary className="cursor-pointer text-xs font-semibold text-primary">Parameters</summary>
          <div className="mt-2">
            <ParamEditor fields={fields} recipe={recipe} versionId={c.version_id} />
          </div>
        </details>
      )}
    </article>
  );
}
