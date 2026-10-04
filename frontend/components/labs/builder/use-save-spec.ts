"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { saveRecipeSpecAction } from "@/lib/labs/builder/actions";
import type { Recipe, RecipeSpec } from "@/lib/labs/builder/types";

export type RecipeRef = Pick<Recipe, "id" | "title" | "revision" | "target_placement" | "spec">;

/** Saves a recipe spec and re-renders the server page (validation, candidates). */
export function useSaveSpec(recipe: RecipeRef) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  const save = (spec: RecipeSpec, success?: string) =>
    startTransition(async () => {
      const res = await saveRecipeSpecAction(recipe, spec);
      if (res.ok) {
        if (success) toast.success(success);
      } else if (res.status === 409) {
        toast.error("This recipe was changed elsewhere. Reloaded the latest version; please redo your change.");
      } else {
        toast.error(res.error ?? "Could not save the recipe.");
      }
      router.refresh();
    });

  return { save, pending };
}
