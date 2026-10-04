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
    description: "The application students debug: its features, history and regression suite.",
  },
  {
    key: "fault", type: "blocks", kinds: ["fault"], mode: "multi", label: "Faults",
    description: "The production bugs planted in the app. Add up to three: chain them, or pool interchangeable ones so each student gets one. Incompatible faults are greyed out with the reason.",
  },
  {
    key: "data", type: "blocks", kinds: ["data"], mode: "multi", label: "Data",
    description: "Seed data for the app's database. Suggested blocks satisfy what the fault needs.",
  },
  {
    key: "services", type: "blocks", kinds: ["stub", "env"], mode: "multi", label: "Stubs & env",
    description: "Fake external services and production-like environment settings.",
  },
  {
    key: "checks", type: "blocks", kinds: ["check"], mode: "multi", label: "Checks",
    description: "Grader probes. The fault sets their parameters; add the checks it references.",
  },
  {
    key: "ticket", type: "blocks", kinds: ["ticket"], mode: "single", panel: "ticket-draft", label: "Ticket",
    description: "How the incident reaches the student. Draft one with AI from the fault's symptom, write your own, or reuse a shared one. Without one, the brief comes from the symptom.",
  },
  {
    key: "guidance", type: "blocks", kinds: ["hints", "rubric"], mode: "single", label: "Hints & rubric",
    description: "Optional overrides of the fault's hint ladder and write-up rubric.",
  },
  {
    key: "randomize", type: "randomize", label: "Randomization",
    description: "Parameters left unpinned become variant axes; every variant is built and verified.",
  },
  {
    key: "build", type: "build", label: "Build & verify",
    description: "Render every variant and run the verification matrix through the real grader.",
  },
  { key: "preview", type: "preview", label: "Preview", description: "Try a verified variant as a student would." },
  { key: "publish", type: "publish", label: "Publish", description: "Place the verified lab in a course section." },
];

export function findStep(key: string | undefined): BuilderStep {
  return BUILDER_STEPS.find((s) => s.key === key) ?? BUILDER_STEPS[0];
}
