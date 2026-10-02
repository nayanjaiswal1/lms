"use client";

import { Ban, Lightbulb } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ParamEditor } from "@/components/labs/builder/param-editor";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { paramFields } from "@/lib/labs/builder/params";
import { withBlock, withoutBlock } from "@/lib/labs/builder/spec";
import type { Candidate } from "@/lib/labs/builder/types";
import { cn } from "@/lib/utils";

interface CandidateCardProps {
  recipe: RecipeRef;
  candidate: Candidate;
  /** Selected blocks this one replaces when added (single-per-kind steps). */
  replaces: string[];
}

export function CandidateCard({ recipe, candidate: c, replaces }: CandidateCardProps) {
  const { save, pending } = useSaveSpec(recipe);
  const fields = paramFields(c.manifest);
  const features = c.manifest?.app?.features ?? [];
  const disabled = !c.compatible && !c.selected;

  return (
    <article
      className={cn("card-base flex flex-col gap-3", c.selected && "border-primary", disabled && "opacity-60")}
    >
      <div className="flex flex-wrap items-start justify-between gap-3">
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
        <p className="text-xs text-muted-foreground">Features: {features.join(", ")}</p>
      )}

      {c.blockers.map((b) => (
        <p className="flex items-start gap-1.5 text-xs text-destructive" key={b}>
          <Ban aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          {b}
        </p>
      ))}
      {c.needs.map((n) => (
        <p className="flex items-start gap-1.5 text-xs text-muted-foreground" key={n}>
          <Lightbulb aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          Needs: {n}
        </p>
      ))}

      <div className="flex flex-wrap gap-2">
        {c.selected ? (
          <Button disabled={pending} variant="outline" onClick={() => save(withoutBlock(recipe.spec, c.version_id))}>
            Remove
          </Button>
        ) : (
          <Button disabled={pending || disabled} onClick={() => save(withBlock(recipe.spec, c.version_id, replaces))}>
            {replaces.length > 0 ? "Use this instead" : "Add"}
          </Button>
        )}
      </div>

      {c.selected && fields.length > 0 && (
        <details className="border-t border-border pt-3">
          <summary className="cursor-pointer text-xs font-semibold text-primary">Parameters</summary>
          <div className="mt-3">
            <ParamEditor fields={fields} recipe={recipe} versionId={c.version_id} />
          </div>
        </details>
      )}
    </article>
  );
}
