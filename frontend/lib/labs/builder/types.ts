// Wire types of the lab-authoring API (backend/internal/labauthor,
// backend/internal/labbuild). Field names mirror the Go JSON tags.

export type IssueSeverity = "error" | "warning" | "info";

interface RecipeIssue {
  code: string;
  block: string;
  message: string;
  severity: IssueSeverity;
}

/** JSON Schema subset used by block params (labauthor/params.go). */
export interface ParamSchema {
  type?: "string" | "integer" | "number" | "boolean" | "array" | "object";
  description?: string;
  enum?: (string | number)[];
  minimum?: number;
  maximum?: number;
  maxLength?: number;
  default?: unknown;
  randomize?: { choices?: (string | number | boolean)[]; range?: { min: number; max: number; step?: number } };
  "x-mf-use"?: string;
}

export interface BlockManifest {
  kind: string;
  id: string;
  version: string;
  stack: string;
  title: string;
  summary: string;
  category: string;
  difficulty: string;
  skills: string[] | null;
  changelog?: string;
  params?: { properties?: Record<string, ParamSchema>; required?: string[] };
  requires?: string[];
  provides?: string[];
  conflicts?: string[];
  app?: { language: string; features: string[] | null; slots: { name: string; type: string }[] | null; services?: string[] };
  ticket?: { template_md?: string; severity?: string; persona?: string; red_herrings?: string[] };
  hints?: { ladder: string[] };
  rubric?: { key_points: string[]; misconceptions?: string[] };
  preset?: { target: string; values: Record<string, unknown> };
  fault?: { chain?: BlockChain };
}

export interface BlockSummary {
  id: string;
  org_id: string | null;
  block_key: string;
  kind: string;
  stack: string;
  latest_version_id: string;
  latest_version: string;
  title: string;
  summary: string;
  category: string;
  difficulty: string;
  skills: string[];
  org_owned: boolean;
}

interface BlockVersionInfo {
  id: string;
  version: string;
  content_hash: string;
  changelog: string;
  manifest: BlockManifest;
  has_payload: boolean;
  yanked_at: string | null;
  yanked_reason: string | null;
  created_at: string;
  recipe_count: number;
  lab_count: number;
}

export interface BlockDetail {
  id: string;
  org_id: string | null;
  block_key: string;
  kind: string;
  stack: string;
  org_owned: boolean;
  versions: BlockVersionInfo[];
}

export type ChainMode = "masks" | "compounds";

/** A fault that follows another fault of the recipe (`after` = its block key). */
export interface BlockChain {
  after: string;
  mode: ChainMode;
}

export interface BlockRef {
  block_version_id: string;
  role?: string;
  pool?: string;
  chain?: BlockChain;
  params?: Record<string, unknown>;
}

export interface RecipeSpec {
  app_range?: string;
  blocks: BlockRef[];
  seed?: number;
  difficulty_override?: string;
}

export type BuildStatus = "queued" | "rendering" | "verifying" | "verified" | "failed";

export interface BuildRef {
  id: string;
  status: BuildStatus;
  recipe_hash: string;
  created_at: string;
  finished_at: string | null;
}

export interface TargetPlacement {
  course_id: string;
  section_id: string;
}

export interface Recipe {
  id: string;
  lab_kind: string;
  title: string;
  spec: RecipeSpec;
  revision: number;
  lab_id: string | null;
  target_placement: TargetPlacement | null;
  created_at: string;
  updated_at: string;
  latest_build?: BuildRef;
  updates_available: number;
  yanked_blocks: number;
}

export interface RecipeBlockView {
  block_version_id: string;
  block_id: string;
  block_key: string;
  kind: string;
  version: string;
  title: string;
  yanked: boolean;
  org_owned: boolean;
}

export interface UpdateAvailable {
  block_id: string;
  block_key: string;
  pinned_version_id: string;
  pinned_version: string;
  pinned_yanked: boolean;
  latest_version_id: string;
  latest_version: string;
  changelog: string;
}

export interface RecipeView {
  recipe: Recipe;
  blocks: RecipeBlockView[];
  updates: UpdateAvailable[];
}

export interface RecipeAnalysis {
  issues: RecipeIssue[];
  valid: boolean;
  recipe_hash: string;
  derived_difficulty: string;
  difficulty: string;
  variant_count: number;
  variant_total: number;
}

export interface Candidate {
  block: BlockSummary;
  version_id: string;
  manifest: BlockManifest | null;
  selected: boolean;
  compatible: boolean;
  blockers: string[];
  needs: string[];
  suggested: boolean;
  /** Fault key this fault must be added chained after (it shares a slot with it). */
  chain_after?: string;
}

interface CheckResult {
  name: string;
  passed: boolean;
  message?: string;
}

interface ModeResult {
  passed: boolean;
  error?: string;
  checks: CheckResult[] | null;
}

export interface RunReport {
  name: string;
  description: string;
  overlay: string;
  passed: boolean;
  expectations: string[] | null;
  failures?: string[];
  seeds: { seed: string; modes: Record<string, ModeResult> }[] | null;
  setup_seconds: number;
  stderr_tail?: string;
  error?: string;
  author_messages?: string[];
}

interface VariantReport {
  variant_key: string;
  passed: boolean;
  runs: RunReport[] | null;
  brief_filled: boolean;
  capture_note?: string;
  pending_runs?: string[];
}

export interface BuildReport {
  error?: string;
  issues?: RecipeIssue[];
  recipe_hash?: string;
  difficulty?: string;
  variant_count?: number;
  render_seconds?: number;
  variants?: VariantReport[];
}

export interface BuildView {
  id: string;
  recipe_id: string;
  recipe_hash: string;
  status: BuildStatus;
  report: BuildReport | null;
  derived_difficulty: string | null;
  created_at: string;
  finished_at: string | null;
  variants: { key: string; brief_md: string }[];
}

export interface TicketDraft {
  draft: string;
  persona: string;
  recipe_hash: string;
  cached: boolean;
}

export interface AffectedLab {
  id: string;
  org_id: string;
  title: string;
}

/** The writable manifest of an org text block (labblock.Manifest subset). */
export interface TextBlockManifest {
  kind: TextBlockKind;
  id?: string;
  title: string;
  summary: string;
  changelog?: string;
  ticket?: { template_md: string; severity?: string; persona?: string; red_herrings?: string[] };
  hints?: { ladder: string[] };
  rubric?: { key_points: string[]; misconceptions?: string[] };
  preset?: { target: string; values: Record<string, unknown> };
}

export type TextBlockKind = "ticket" | "hints" | "rubric" | "preset";

export interface PublishResult {
  lab_id: string;
  task_version_id: string;
  version: number;
  republished: boolean;
  unchanged: boolean;
}

export interface PickerOption {
  id: string;
  title: string;
}

export interface CoursePickerOption extends PickerOption {
  slug: string;
}
