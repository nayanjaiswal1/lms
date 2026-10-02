import { parseAsString } from "nuqs/server";

// Block-library filters (app/(app)/teach/debug-labs/blocks): shared by the
// server page and the client filter bar so the URL is the single source of truth.

/** URL value meaning "no filter". */
export const BLOCKS_ALL = "all";

export const blockLibraryParsers = {
  kind: parseAsString.withDefault(BLOCKS_ALL),
  stack: parseAsString.withDefault(BLOCKS_ALL),
};

/** Mirrors labkinds DebugKind.BlockKinds() + the shared preset kind. */
export const BLOCK_KIND_OPTIONS = ["app", "fault", "data", "stub", "env", "check", "ticket", "hints", "rubric", "preset"].map(
  (k) => ({ value: k, label: k.charAt(0).toUpperCase() + k.slice(1) }),
);

/** Mirrors labblock.Stacks. */
export const BLOCK_STACK_OPTIONS = [
  { value: "django", label: "Django" },
  { value: "fastapi", label: "FastAPI" },
  { value: "react", label: "React" },
  { value: "fullstack", label: "Full stack" },
  { value: "any", label: "Any stack" },
];
