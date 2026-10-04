import type { BlockChain, BlockRef, RecipeSpec } from "@/lib/labs/builder/types";

// Pure recipe-spec edits used by the wizard. The server re-validates every
// saved spec; these only express the author's intent.

/** Adds a block; `replaceVersionIds` are removed first (single-per-kind steps). */
export function withBlock(spec: RecipeSpec, versionId: string, replaceVersionIds: readonly string[] = []): RecipeSpec {
  const drop = new Set(replaceVersionIds);
  return { ...spec, blocks: [...spec.blocks.filter((b) => !drop.has(b.block_version_id)), { block_version_id: versionId }] };
}

/** Removes a block. Faults chained after it (`blockKey`) are released, since a chain to a missing fault is invalid. */
export function withoutBlock(spec: RecipeSpec, versionId: string, blockKey?: string): RecipeSpec {
  return {
    ...spec,
    blocks: spec.blocks
      .filter((b) => b.block_version_id !== versionId)
      .map((b): BlockRef => (blockKey && b.chain?.after === blockKey ? { ...b, chain: undefined } : b)),
  };
}

function withRefField<K extends "pool" | "chain">(spec: RecipeSpec, versionId: string, key: K, value: BlockRef[K] | undefined): RecipeSpec {
  return { ...spec, blocks: spec.blocks.map((b): BlockRef => (b.block_version_id === versionId ? { ...b, [key]: value } : b)) };
}

/** Puts a fault in a pool (one member is picked per variant), or with `undefined` takes it out. */
export function withPool(spec: RecipeSpec, versionId: string, pool: string | undefined): RecipeSpec {
  return withRefField(spec, versionId, "pool", pool);
}

/** Chains a fault after another (`undefined` = independent). */
export function withChain(spec: RecipeSpec, versionId: string, chain: BlockChain | undefined): RecipeSpec {
  return withRefField(spec, versionId, "chain", chain);
}

/** Moves a pinned block to another version of the same block, keeping its role, pool, chain and params. */
export function withVersion(spec: RecipeSpec, fromVersionId: string, toVersionId: string): RecipeSpec {
  return {
    ...spec,
    blocks: spec.blocks.map((b): BlockRef => (b.block_version_id === fromVersionId ? { ...b, block_version_id: toVersionId } : b)),
  };
}

export function refOf(spec: RecipeSpec, versionId: string): BlockRef | undefined {
  return spec.blocks.find((b) => b.block_version_id === versionId);
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
