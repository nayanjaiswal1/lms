import type { Metadata } from "next";
import { BackLink } from "@/components/labs/builder/back-link";
import { BuildStatusBadge } from "@/components/labs/builder/build-status-badge";
import { BuilderStepper } from "@/components/labs/builder/builder-stepper";
import { StepBody } from "@/components/labs/builder/step-body";
import { ValidationPanel } from "@/components/labs/builder/validation-panel";
import { getRecipeView, requireLabAuthor, getRecipeAnalysis } from "@/lib/labs/builder/server";
import { currentVerifiedBuild } from "@/lib/labs/builder/build";
import { completedSteps, findStep } from "@/lib/labs/builder/steps";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Debug lab builder" };

interface RecipePageProps {
  params: Promise<{ recipeId: string }>;
  searchParams: Promise<{ step?: string; course?: string }>;
}

// The builder wizard (docs/debug-labs.md B4): step in the URL, the recipe saved
// on every change, and the server's composition validator re-run on each render.
export default async function RecipeBuilderPage({ params, searchParams }: RecipePageProps) {
  await requireLabAuthor();
  const [{ recipeId }, { step: stepKey, course }] = await Promise.all([params, searchParams]);
  const step = findStep(stepKey);
  const [view, analysis] = await Promise.all([getRecipeView(recipeId), getRecipeAnalysis(recipeId)]);

  const recipe = view.recipe;
  const done = completedSteps(view.blocks, currentVerifiedBuild(recipe, analysis) !== null, Boolean(recipe.lab_id));

  return (
    <main className="page-container flex flex-col gap-4">
      <BackLink href={ROUTES.LAB_BUILDER} label="All debug labs" />
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="page-title min-w-0 truncate">{recipe.title}</h1>
        <BuildStatusBadge status={recipe.latest_build?.status ?? null} />
      </div>
      <BuilderStepper current={step.key} done={done} recipeId={recipeId} />
      <ValidationPanel analysis={analysis} recipe={recipe} updates={view.updates} />
      <section aria-label={step.label} className="min-w-0">
        <p className="mb-4 text-sm text-muted-foreground">{step.description}</p>
        <StepBody analysis={analysis} courseParam={course} step={step} view={view} />
      </section>
    </main>
  );
}
