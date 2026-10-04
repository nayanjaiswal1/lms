import type { Metadata } from "next";
import { BackLink } from "@/components/labs/builder/back-link";
import { BuildStatusBadge } from "@/components/labs/builder/build-status-badge";
import { BuilderStepper } from "@/components/labs/builder/builder-stepper";
import { StepBody } from "@/components/labs/builder/step-body";
import { ValidationPanel } from "@/components/labs/builder/validation-panel";
import { getRecipeView, requireLabAuthor, validateRecipe } from "@/lib/labs/builder/server";
import { findStep } from "@/lib/labs/builder/steps";
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
  const [view, analysis] = await Promise.all([getRecipeView(recipeId), validateRecipe(recipeId)]);

  return (
    <main className="page-container flex flex-col gap-6">
      <BackLink href={ROUTES.LAB_BUILDER} label="All debug labs" />
      <div className="page-header">
        <div className="min-w-0">
          <h1 className="page-title">{view.recipe.title}</h1>
          <p className="text-sm text-muted-foreground">{step.description}</p>
        </div>
        <BuildStatusBadge status={view.recipe.latest_build?.status ?? null} />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div className="lg:col-span-2">
          <BuilderStepper current={step.key} recipeId={recipeId} />
        </div>
        <section aria-label={step.label} className="min-w-0 lg:col-span-7">
          <h2 className="mb-4 text-lg font-semibold">{step.label}</h2>
          <StepBody analysis={analysis} courseParam={course} step={step} view={view} />
        </section>
        <div className="lg:col-span-3">
          <ValidationPanel analysis={analysis} recipe={view.recipe} updates={view.updates} />
        </div>
      </div>
    </main>
  );
}
