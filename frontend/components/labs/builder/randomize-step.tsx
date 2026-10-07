import { Shuffle } from "lucide-react";
import { AxisControl } from "@/components/labs/builder/axis-control";
import type { RecipeRef } from "@/components/labs/builder/use-save-spec";
import { FAULT_POOL_OPTIONS } from "@/lib/labs/builder/options";
import { axisValues, isRandomizable } from "@/lib/labs/builder/params";
import { getBlock } from "@/lib/labs/builder/server";
import { paramsOf } from "@/lib/labs/builder/spec";
import type { RecipeAnalysis, RecipeBlockView } from "@/lib/labs/builder/types";

interface RandomizeStepProps {
  recipe: RecipeRef;
  blocks: RecipeBlockView[];
  analysis: RecipeAnalysis;
}

/** Variant axes: every randomizable parameter of the selected blocks (docs/debug-labs.md B6). */
export async function RandomizeStep({ recipe, blocks, analysis }: RandomizeStepProps) {
  const details = await Promise.all(blocks.map((b) => getBlock(b.block_id)));
  const axes = blocks.flatMap((b, i) => {
    const manifest = details[i].versions.find((v) => v.id === b.block_version_id)?.manifest;
    return Object.entries(manifest?.params?.properties ?? {})
      .filter(([, schema]) => isRandomizable(schema))
      .map(([name, schema]) => ({ block: b, name, values: axisValues(schema) }));
  });

  const pools = new Map<string, string[]>();
  for (const ref of recipe.spec.blocks) {
    const title = blocks.find((b) => b.block_version_id === ref.block_version_id)?.title;
    if (ref.pool && title) pools.set(ref.pool, [...(pools.get(ref.pool) ?? []), title]);
  }

  if (axes.length === 0 && pools.size === 0) {
    return (
      <div className="empty-state">
        <Shuffle aria-hidden className="empty-state-icon" />
        <p>None of the selected blocks has randomizable parameters, so this lab has one variant.</p>
      </div>
    );
  }
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">
        {analysis.variant_count} variant{analysis.variant_count === 1 ? "" : "s"} will be built and verified
        {analysis.variant_total > analysis.variant_count ? ` (capped from ${analysis.variant_total})` : ""}.
      </p>
      {[...pools].map(([pool, titles]) => (
        <p className="text-sm" key={pool}>
          <span className="font-semibold">{FAULT_POOL_OPTIONS.find((p) => p.value === pool)?.label ?? pool}</span>: each student
          gets one of {titles.join(", ")}.
        </p>
      ))}
      <ul className="card-base flex flex-col divide-y divide-border p-0">
        {axes.map((a) => (
          <li className="flex flex-col gap-2 px-4 py-3" key={`${a.block.block_version_id}:${a.name}`}>
            <p className="text-sm font-semibold">
              {a.block.title} <span className="font-mono text-xs text-muted-foreground">{a.name}</span>
            </p>
            <AxisControl
              name={a.name}
              pinned={paramsOf(recipe.spec, a.block.block_version_id)[a.name]}
              recipe={recipe}
              values={a.values}
              versionId={a.block.block_version_id}
            />
          </li>
        ))}
      </ul>
    </div>
  );
}
