import { BuildReport } from "@/components/labs/builder/build-report";
import { BuildStatusBadge } from "@/components/labs/builder/build-status-badge";
import { StartBuildButton } from "@/components/labs/builder/start-build-button";
import { RefreshPoller } from "@/components/shared/refresh-poller";
import { isBuildInFlight } from "@/lib/labs/builder/build";
import { getBuild } from "@/lib/labs/builder/server";
import type { RecipeAnalysis, Recipe } from "@/lib/labs/builder/types";

interface BuildStepProps {
  recipe: Recipe;
  analysis: RecipeAnalysis;
}

/** Build & verify: start a build of the current composition and follow its matrix live. */
export async function BuildStep({ recipe, analysis }: BuildStepProps) {
  const latest = recipe.latest_build;
  const build = latest ? await getBuild(latest.id) : null;
  const current = latest !== undefined && latest.recipe_hash === analysis.recipe_hash;
  const inFlight = current && isBuildInFlight(latest.status);

  let label = "Build & verify";
  if (current && latest.status === "failed") label = "Retry build";

  return (
    <div className="flex flex-col gap-3">
      <RefreshPoller active={inFlight} />
      <div className="flex flex-wrap items-center gap-3">
        {!(current && (inFlight || latest.status === "verified")) && (
          <StartBuildButton disabled={!analysis.valid} label={label} recipeId={recipe.id} />
        )}
        {build && <BuildStatusBadge status={build.status} />}
        {!analysis.valid && <p className="text-sm text-muted-foreground">Fix the validation errors first.</p>}
      </div>
      {build && !current && (
        <p className="text-sm text-muted-foreground">
          Composition changed since this build; build again to verify.
        </p>
      )}
      {build && <BuildReport build={build} />}
    </div>
  );
}
