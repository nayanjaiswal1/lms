import type { ChainMode, TextBlockKind } from "@/lib/labs/builder/types";

// Option sets of the Phase 2 builder controls (docs/debug-labs.md B2/B4/B6).

/** Mirrors labblock.ChainMasks / ChainCompounds. */
export const CHAIN_MODE_OPTIONS: readonly { value: ChainMode; label: string; hint: string }[] = [
  { value: "masks", label: "Masks", hint: "Its symptom only appears once the earlier fault is fixed." },
  { value: "compounds", label: "Compounds", hint: "Both symptoms are visible at once." },
];

/** Fault pools are named here so a recipe can't invent unbounded names; one member of each pool is picked per variant. */
export const FAULT_POOL_OPTIONS: readonly { value: string; label: string }[] = [
  { value: "pool-a", label: "Pool A" },
  { value: "pool-b", label: "Pool B" },
  { value: "pool-c", label: "Pool C" },
];

/** Reporter voices offered for an AI-drafted ticket (the server accepts any <= 60 chars). */
export const TICKET_PERSONA_OPTIONS: readonly { value: string; label: string }[] = [
  { value: "frustrated customer-support lead", label: "Frustrated support lead" },
  { value: "calm on-call SRE", label: "Calm on-call SRE" },
  { value: "non-technical product manager", label: "Non-technical product manager" },
  { value: "terse senior engineer", label: "Terse senior engineer" },
];

export const TICKET_SEVERITY_OPTIONS: readonly { value: string; label: string }[] = [
  { value: "low", label: "Low" },
  { value: "medium", label: "Medium" },
  { value: "high", label: "High" },
  { value: "critical", label: "Critical" },
];

/** Mirrors labblock.TextKinds: the kinds an org may author in the UI. */
export const TEXT_BLOCK_KINDS: readonly { kind: TextBlockKind; label: string; description: string }[] = [
  { kind: "ticket", label: "Ticket", description: "The incident report students receive." },
  { kind: "hints", label: "Hints", description: "A three-level hint ladder that replaces the fault's." },
  { kind: "rubric", label: "Rubric", description: "Key points and misconceptions for the write-up review." },
  { kind: "preset", label: "Parameter preset", description: "Saved parameter values for one block." },
];

/** Mirrors labauthor hintLadderLen. */
export const HINT_LEVELS = 3;
