"use client";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useSaveSpec, type RecipeRef } from "@/components/labs/builder/use-save-spec";
import { CHAIN_MODE_OPTIONS, FAULT_POOL_OPTIONS } from "@/lib/labs/builder/options";
import { refOf, withChain, withPool } from "@/lib/labs/builder/spec";
import type { BlockChain, ChainMode } from "@/lib/labs/builder/types";

/** Select value meaning "none" (a Radix Select item can't be ""). */
const NONE = "__none";

export interface FaultPeer {
  key: string;
  title: string;
}

interface FaultLinksProps {
  recipe: RecipeRef;
  versionId: string;
  /** The other faults in the recipe this one can follow. */
  peers: FaultPeer[];
  /** The chain the block's own manifest declares, if any. */
  declaredChain: BlockChain | undefined;
}

/** Chain and pool controls of one selected fault (docs/debug-labs.md B2 rule 4, B6). */
export function FaultLinks({ recipe, versionId, peers, declaredChain }: FaultLinksProps) {
  const { save, pending } = useSaveSpec(recipe);
  const ref = refOf(recipe.spec, versionId);
  const chain = ref?.chain ?? declaredChain;
  const mode = CHAIN_MODE_OPTIONS.find((m) => m.value === chain?.mode);
  const setChain = (next: BlockChain | undefined) => save(withChain(recipe.spec, versionId, next));

  return (
    <div className="grid gap-3 border-t border-border pt-3 sm:grid-cols-2">
      <div className="flex min-w-0 flex-col gap-1.5">
        <span className="text-xs font-semibold">Follows</span>
        <Select
          disabled={pending || peers.length === 0}
          value={chain?.after ?? NONE}
          onValueChange={(v) => setChain(v === NONE ? undefined : { after: v, mode: chain?.mode ?? "masks" })}
        >
          <SelectTrigger aria-label="Chain after fault" className="w-full">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {!declaredChain && <SelectItem value={NONE}>Independent</SelectItem>}
            {peers.map((p) => (
              <SelectItem key={p.key} value={p.key}>
                {p.title}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {chain && (
          <Select
            disabled={pending}
            value={chain.mode}
            onValueChange={(v) => setChain({ after: chain.after, mode: v as ChainMode })}
          >
            <SelectTrigger aria-label="Chain mode" className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {CHAIN_MODE_OPTIONS.map((m) => (
                <SelectItem key={m.value} value={m.value}>
                  {m.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        <p className="text-xs text-muted-foreground">
          {mode?.hint ?? (peers.length === 0 ? "Add a second fault to chain them." : "Both symptoms are independent.")}
        </p>
      </div>
      <div className="flex min-w-0 flex-col gap-1.5">
        <span className="text-xs font-semibold">Pool</span>
        <Select
          disabled={pending}
          value={ref?.pool ?? NONE}
          onValueChange={(v) => save(withPool(recipe.spec, versionId, v === NONE ? undefined : v))}
        >
          <SelectTrigger aria-label="Fault pool" className="w-full">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={NONE}>Always included</SelectItem>
            {FAULT_POOL_OPTIONS.map((p) => (
              <SelectItem key={p.value} value={p.value}>
                {p.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <p className="text-xs text-muted-foreground">
          Faults in the same pool are alternatives: each student gets one. Members must share a category and stay within one
          difficulty level.
        </p>
      </div>
    </div>
  );
}
