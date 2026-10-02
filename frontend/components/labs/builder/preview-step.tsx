import Link from "next/link";
import { PreviewLauncher } from "@/components/labs/builder/preview-launcher";
import { currentVerifiedBuild } from "@/lib/labs/builder/build";
import { getBuild } from "@/lib/labs/builder/server";
import type { Recipe, RecipeAnalysis } from "@/lib/labs/builder/types";
import ROUTES from "@/lib/routes";

interface PreviewStepProps {
  recipe: Recipe;
  analysis: RecipeAnalysis;
}

export async function PreviewStep({ recipe, analysis }: PreviewStepProps) {
  const verified = currentVerifiedBuild(recipe, analysis);
  if (!verified) {
    return (
      <p className="text-sm text-muted-foreground">
        Preview needs a verified build of the current composition.{" "}
        <Link className="text-primary hover:underline" href={ROUTES.labBuilderRecipe(recipe.id, "build")}>
          Go to Build &amp; verify
        </Link>
      </p>
    );
  }
  const build = await getBuild(verified.id);
  const options = build.variants.map((v) => ({ label: v.key, value: v.key }));
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-muted-foreground">
        The preview is a real sandbox session of the verified build, marked as a test session.
      </p>
      <PreviewLauncher buildId={build.id} variantOptions={options} />
    </div>
  );
}
