"use client";

import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { withParam } from "@/lib/labs/builder/spec";

interface AxisControlProps {
  recipe: RecipeRef;
  versionId: string;
  name: string;
  values: (string | number | boolean)[];
  /** The pinned value, or undefined when the parameter varies. */
  pinned: unknown;
}

/** Pins a randomizable parameter to one value, or lets it vary across variants. */
export function AxisControl({ recipe, versionId, name, values, pinned }: AxisControlProps) {
  const { save, pending } = useSaveSpec(recipe);

  if (pinned !== undefined) {
    return (
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-sm">
          Pinned to <span className="font-mono">{String(pinned)}</span>
        </span>
        <Button disabled={pending} variant="outline" onClick={() => save(withParam(recipe.spec, versionId, name, undefined))}>
          Vary it
        </Button>
      </div>
    );
  }
  return (
    <div className="flex flex-wrap items-center gap-3">
      <span className="text-sm">Varies over {values.map(String).join(", ")}</span>
      <Select
        disabled={pending}
        onValueChange={(v) => save(withParam(recipe.spec, versionId, name, values.find((x) => String(x) === v)))}
      >
        <SelectTrigger aria-label={`Pin ${name}`} className="w-full sm:w-40">
          <SelectValue placeholder="Pin to…" />
        </SelectTrigger>
        <SelectContent>
          {values.map((v) => (
            <SelectItem key={String(v)} value={String(v)}>
              {String(v)}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
