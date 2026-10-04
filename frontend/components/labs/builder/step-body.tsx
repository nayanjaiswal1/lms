import { BlockStep } from "@/components/labs/builder/block-step";
import { BuildStep } from "@/components/labs/builder/build-step";
import { PreviewStep } from "@/components/labs/builder/preview-step";
import { PublishStep } from "@/components/labs/builder/publish-step";
import { RandomizeStep } from "@/components/labs/builder/randomize-step";
import type { BuilderStep } from "@/lib/labs/builder/steps";
import type { RecipeAnalysis, RecipeView } from "@/lib/labs/builder/types";

interface StepBodyProps {
  step: BuilderStep;
  view: RecipeView;
  analysis: RecipeAnalysis;
  courseParam: string | undefined;
}

export function StepBody({ step, view, analysis, courseParam }: StepBodyProps) {
  const recipe = view.recipe;
  switch (step.type) {
    case "blocks":
      return <BlockStep recipe={recipe} step={step} valid={analysis.valid} />;
    case "randomize":
      return <RandomizeStep analysis={analysis} blocks={view.blocks} recipe={recipe} />;
    case "build":
      return <BuildStep analysis={analysis} recipe={recipe} />;
    case "preview":
      return <PreviewStep analysis={analysis} recipe={recipe} />;
    case "publish":
      return <PublishStep analysis={analysis} courseParam={courseParam} recipe={recipe} />;
  }
}
