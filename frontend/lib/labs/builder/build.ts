import type { BuildRef, BuildStatus, Recipe, RecipeAnalysis } from "@/lib/labs/builder/types";

export function isBuildInFlight(status: BuildStatus | undefined): boolean {
  return status === "queued" || status === "rendering" || status === "verifying";
}

/** The recipe's latest build if it verified the composition as it is now (the only publishable one). */
export function currentVerifiedBuild(recipe: Recipe, analysis: RecipeAnalysis): BuildRef | null {
  const b = recipe.latest_build;
  return b && b.status === "verified" && b.recipe_hash === analysis.recipe_hash ? b : null;
}
