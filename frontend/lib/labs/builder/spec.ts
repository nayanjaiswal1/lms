import type { BlockRef, RecipeSpec } from "@/lib/labs/builder/types";

// Pure recipe-spec edits used by the wizard. The server re-validates every
// saved spec; these only express the author's intent.

/** Adds a block; `replaceVersionIds` are removed first (single-per-kind steps). */
export function withBlock(spec: RecipeSpec, versionId: string, replaceVersionIds: readonly string[] = []): RecipeSpec {
  const drop = new Set(replaceVersionIds);
  return { ...spec, blocks: [...spec.blocks.filter((b) => !drop.has(b.block_version_id)), { block_version_id: versionId }] };
}

export function withoutBlock(spec: RecipeSpec, versionId: string): RecipeSpec {
  return { ...spec, blocks: spec.blocks.filter((b) => b.block_version_id !== versionId) };
}

/** Sets (or, with `undefined`, clears) one parameter of one block. A cleared
 * randomizable parameter becomes a variant axis. */
export function withParam(spec: RecipeSpec, versionId: string, name: string, value: unknown): RecipeSpec {
  return {
    ...spec,
    blocks: spec.blocks.map((b): BlockRef => {
      if (b.block_version_id !== versionId) return b;
      const params = Object.fromEntries(Object.entries(b.params ?? {}).filter(([k]) => k !== name));
      if (value !== undefined) params[name] = value;
      return { ...b, params: Object.keys(params).length > 0 ? params : undefined };
    }),
  };
}

export function paramsOf(spec: RecipeSpec, versionId: string): Record<string, unknown> {
  return spec.blocks.find((b) => b.block_version_id === versionId)?.params ?? {};
}
