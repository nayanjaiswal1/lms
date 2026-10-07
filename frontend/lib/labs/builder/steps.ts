// The builder wizard's steps (docs/debug-labs.md B4). Block steps pick blocks
// of the listed kinds; "single" allows at most one block per kind.

export type BlockStepMode = "single" | "multi";

interface BaseStep {
  key: string;
  label: string;
  description: string;
}

export interface BlockStep extends BaseStep {
  type: "blocks";
  kinds: readonly string[];
  mode: BlockStepMode;
  /** Extra panel rendered under the candidates. */
  panel?: "ticket-draft";
}

export interface CustomStep extends BaseStep {
  type: "randomize" | "build" | "preview" | "publish";
}

export type BuilderStep = BlockStep | CustomStep;

export const BUILDER_STEPS: readonly BuilderStep[] = [
  {
    key: "app", type: "blocks", kinds: ["app"], mode: "single", label: "Base app",
    description: "The application students debug.",
  },
  {
    key: "fault", type: "blocks", kinds: ["fault"], mode: "multi", label: "Faults",
    description: "Bugs planted in the app (up to three). Chain them or pool interchangeable ones.",
  },
  {
    key: "data", type: "blocks", kinds: ["data"], mode: "multi", label: "Data",
    description: "Seed data for the app's database.",
  },
  {
    key: "services", type: "blocks", kinds: ["stub", "env"], mode: "multi", label: "Stubs & env",
    description: "Fake external services and environment settings.",
  },
  {
    key: "checks", type: "blocks", kinds: ["check"], mode: "multi", label: "Checks",
    description: "Grader probes the fault references.",
  },
  {
    key: "ticket", type: "blocks", kinds: ["ticket"], mode: "single", panel: "ticket-draft", label: "Ticket",
    description: "How the incident reaches the student. Optional; defaults to the fault's symptom.",
  },
  {
    key: "guidance", type: "blocks", kinds: ["hints", "rubric"], mode: "single", label: "Hints & rubric",
    description: "Optional overrides of the hint ladder and write-up rubric.",
  },
  {
    key: "randomize", type: "randomize", label: "Randomization",
    description: "Unpinned parameters become variant axes.",
  },
  {
    key: "build", type: "build", label: "Build & verify",
    description: "Render every variant and verify it with the real grader.",
  },
  { key: "preview", type: "preview", label: "Preview", description: "Try a verified variant as a student would." },
  { key: "publish", type: "publish", label: "Publish", description: "Place the verified lab in a course section." },
];

export function findStep(key: string | undefined): BuilderStep {
  return BUILDER_STEPS.find((s) => s.key === key) ?? BUILDER_STEPS[0];
}

/** Keys of the steps that already hold what they need (shown as done in the stepper). */
export function completedSteps(
  blocks: readonly { kind: string }[],
  verified: boolean,
  published: boolean,
): Set<string> {
  const done = new Set<string>();
  for (const s of BUILDER_STEPS) {
    if (s.type === "blocks" && blocks.some((b) => s.kinds.includes(b.kind))) done.add(s.key);
    if (s.type === "build" && verified) done.add(s.key);
    if (s.type === "publish" && published) done.add(s.key);
  }
  return done;
}
