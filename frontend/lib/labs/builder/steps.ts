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
    key: "fault", type: "blocks", kinds: ["fault"], mode: "single", label: "Fault",
    description: "The production bug planted in the app. Incompatible faults are greyed out with the reason.",
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
    key: "ticket", type: "blocks", kinds: ["ticket"], mode: "single", label: "Ticket",
    description: "How the incident reaches the student. Without one, the brief comes from the fault's symptom.",
  },
  {
    key: "checks", type: "blocks", kinds: ["check"], mode: "multi", label: "Checks",
    description: "Grader probes. The fault sets their parameters; add the checks it references.",
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
