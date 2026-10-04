"use client";

import { Button } from "@/components/ui/button";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { withVersion } from "@/lib/labs/builder/spec";
import type { UpdateAvailable } from "@/lib/labs/builder/types";

interface UpdateListProps {
  recipe: RecipeRef;
  updates: UpdateAvailable[];
}

/** Pinned blocks with a newer version, or a replacement for a yanked one. Taking one is a new recipe revision: rebuild, re-verify, republish. */
export function UpdateList({ recipe, updates }: UpdateListProps) {
  const { save, pending } = useSaveSpec(recipe);

  return (
    <div className="flex flex-col gap-3 border-t border-border pt-3 text-xs">
      <p className="font-semibold">Updates available</p>
      {updates.map((u) => (
        <div className="flex flex-col gap-1" key={u.block_id}>
          <p className="break-words">
            <span className="font-mono">{u.block_key}</span> {u.pinned_version} → {u.latest_version}
          </p>
          {u.pinned_yanked && <p className="text-destructive">The pinned version was yanked and can no longer be built.</p>}
          {u.changelog && <p className="text-muted-foreground">{u.changelog}</p>}
          <Button
            className="self-start"
            disabled={pending}
            size="sm"
            variant="outline"
            onClick={() =>
              save(
                withVersion(recipe.spec, u.pinned_version_id, u.latest_version_id),
                `${u.block_key} moved to ${u.latest_version}. Rebuild to verify it.`,
              )
            }
          >
            {u.pinned_yanked ? "Replace yanked version" : "Take update"}
          </Button>
        </div>
      ))}
    </div>
  );
}
