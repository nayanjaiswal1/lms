// Shared zod schema + option lists for the assessment config form — used by
// both the create form and the edit-settings form so the two never drift.
import { z } from "zod";
import { ASSESSMENT_PARENT_TYPE } from "@/lib/constants";
import type { ProctoringConfig } from "@/lib/assessments/types";

const numeric = z.string().refine((v) => v !== "" && !Number.isNaN(Number(v)), "Enter a number.");

// Only the two parent types a user picks directly when creating a test from
// this generic form. course/module/roadmap/batch (see ValidParentTypes on the
// backend) are set programmatically by their own builders — never chosen here.
export const ASSESSMENT_SCOPE_OPTIONS = [
  {
    value: ASSESSMENT_PARENT_TYPE.STANDALONE,
    label: "Standalone",
    description: "A regular test — assign it to batches or individual students once published.",
  },
  {
    value: ASSESSMENT_PARENT_TYPE.HIRING,
    label: "Hiring / Recruitment",
    description: "Adds a public candidate link — external applicants take it with just their name and email, no account.",
  },
] as const;

export const FULLSCREEN_EXIT_OPTIONS = [
  { value: "pause",       label: "Pause timer",        description: "Freeze the clock; student must return to fullscreen to resume" },
  { value: "continue",    label: "Keep timer running",  description: "Hide questions but keep the clock running — no free breaks" },
  { value: "auto_submit", label: "Auto-submit",         description: "Immediately submit the attempt when fullscreen is exited" },
] as const;

export const ASSESSMENT_MODE_OPTIONS = [
  { value: "practice",  label: "Practice / understanding check", description: "Self-check or practice run — no lockdown, no camera, no violation tracking." },
  { value: "proctored", label: "Proctored exam",                 description: "Formal exam — full anti-cheat lockdown and monitoring." },
] as const;

export const AssessmentConfigSchema = z.object({
  mode: z.enum(["practice", "proctored"]),
  title: z.string().min(3, "Title is too short."),
  description: z.string().optional(),
  duration_minutes: numeric,
  pass_percentage: numeric,
  max_attempts: numeric,
  shuffle_questions: z.boolean(),
  shuffle_options: z.boolean(),
  allow_backtrack: z.boolean(),
  show_results: z.boolean(),
  require_fullscreen: z.boolean(),
  fullscreen_exit_action: z.enum(["pause", "continue", "auto_submit"]),
  block_copy_paste: z.boolean(),
  block_right_click: z.boolean(),
  block_devtools: z.boolean(),
  max_tab_switches: numeric,
  max_focus_loss: numeric,
  auto_submit_on_violation: z.boolean(),
  require_camera: z.boolean(),
  allow_secondary_camera: z.boolean(),
});
export type AssessmentConfigFormData = z.infer<typeof AssessmentConfigSchema>;

export const SETTING_TOGGLES: { name: keyof AssessmentConfigFormData; label: string; description: string }[] = [
  { name: "shuffle_questions", label: "Shuffle questions", description: "Present questions in a different order for every student." },
  { name: "shuffle_options", label: "Shuffle options", description: "Randomize the order of answer choices within each question." },
  { name: "allow_backtrack", label: "Allow going back", description: "Students can revisit and change answers to earlier questions." },
  { name: "show_results", label: "Show results to student", description: "Reveal the score as soon as the attempt is submitted." },
];

export const PROCTOR_TOGGLES: { name: keyof AssessmentConfigFormData; label: string; description: string }[] = [
  { name: "require_fullscreen", label: "Require fullscreen", description: "The attempt can only be taken in fullscreen mode." },
  { name: "block_copy_paste", label: "Block copy / paste", description: "Disable clipboard actions inside the test window." },
  { name: "block_right_click", label: "Block right-click", description: "Disable the context menu for the duration of the attempt." },
  { name: "block_devtools", label: "Block dev tools", description: "Detect and block browser developer tools." },
  { name: "auto_submit_on_violation", label: "Auto-submit on violation", description: "Submit the attempt automatically once a violation limit is hit." },
  { name: "require_camera", label: "Require camera (webcam preflight)", description: "Student must pass a webcam check before starting." },
  { name: "allow_secondary_camera", label: "Allow secondary phone camera", description: "Permit a second camera angle streamed from a paired phone." },
];

// A record with any proctoring flag on is treated as "proctored" mode for the
// initial radio selection — the persisted data has no separate mode field.
export function modeFromProctoring(p: ProctoringConfig): "practice" | "proctored" {
  return p.require_fullscreen ||
    p.block_copy_paste ||
    p.block_right_click ||
    p.block_devtools ||
    p.max_tab_switches > 0 ||
    p.max_focus_loss > 0 ||
    p.auto_submit_on_violation ||
    p.require_camera ||
    p.allow_secondary_camera
    ? "proctored"
    : "practice";
}

export function buildProctoringPayload(data: AssessmentConfigFormData): ProctoringConfig {
  if (data.mode !== "proctored") {
    return {
      require_fullscreen: false,
      fullscreen_exit_action: "pause",
      block_copy_paste: false,
      block_right_click: false,
      block_devtools: false,
      max_tab_switches: 0,
      max_focus_loss: 0,
      auto_submit_on_violation: false,
      heartbeat_seconds: 15,
      require_camera: false,
      allow_secondary_camera: false,
    };
  }
  return {
    require_fullscreen: data.require_fullscreen,
    fullscreen_exit_action: data.fullscreen_exit_action,
    block_copy_paste: data.block_copy_paste,
    block_right_click: data.block_right_click,
    block_devtools: data.block_devtools,
    max_tab_switches: Number(data.max_tab_switches),
    max_focus_loss: Number(data.max_focus_loss),
    auto_submit_on_violation: data.auto_submit_on_violation,
    heartbeat_seconds: 15,
    require_camera: data.require_camera,
    allow_secondary_camera: data.allow_secondary_camera,
  };
}
