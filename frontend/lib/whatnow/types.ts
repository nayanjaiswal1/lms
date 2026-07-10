// What Now? contract types — the single source of truth for everything the UI renders.

export type Energy = "sharp" | "tired";

export type ChipKind = "deadline" | "category" | "duration" | "vague";

export interface Chip {
  id: string;
  kind: ChipKind;
  label: string;
  /** machine value: ISO date for deadline, minutes for duration, etc. */
  value?: string;
}

export type TaskStatus =
  | "inbox"
  | "planned"
  | "active"
  | "paused"
  | "done"
  | "decayed";

export interface Task {
  id: string;
  title: string;
  status: TaskStatus;
  rationale?: string;
  trigger?: string;
  durationMin?: number;
  deadline?: string;
  category?: string;
  vague?: boolean;
  chips?: Chip[];
  resumeNote?: string;
  dependsOn?: string[];
  createdAt?: string;
  completedAt?: string;
}

export interface NowResponse {
  primary: Task | null;
  alternatives: Task[];
  rationale: string;
}

export interface CompleteResponse {
  unlockedTasks: Task[];
}

export type StuckReason =
  | "too_big"
  | "not_sure_it_matters"
  | "deadline_unreal"
  | "cant_focus";

export interface StuckResolution {
  message: string;
  /** optional replacement/adjusted task the backend proposes */
  task?: Task;
}

export interface BreakdownStep {
  id: string;
  title: string;
  durationMin?: number;
}

export interface BreakdownProposal {
  taskId: string;
  steps: BreakdownStep[];
}

export interface PlanToday {
  tasks: Task[];
  cap: number;
  /** how many the user typically finishes in a day */
  throughput: number;
}

export interface WeeklyRecap {
  completed: number;
  revived: number;
  released: number;
  summary: string;
}

export type TaskPatch = Partial<
  Pick<
    Task,
    | "title"
    | "status"
    | "trigger"
    | "durationMin"
    | "deadline"
    | "category"
    | "chips"
    | "resumeNote"
  >
> & {
  /** promote (true) or un-promote (false) this task as the hard "do this now" override */
  pinned?: boolean;
};
