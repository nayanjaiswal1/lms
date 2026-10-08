// What Now? contract types — the single source of truth for everything the UI renders.

export type Energy = "sharp" | "tired";

type ChipKind = "deadline" | "category" | "duration" | "vague";

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
  duration_min?: number;
  deadline?: string;
  category?: string;
  vague?: boolean;
  chips?: Chip[];
  resume_note?: string;
  depends_on?: string[];
  created_at?: string;
  completed_at?: string;
}

export interface NowResponse {
  primary: Task | null;
  alternatives: Task[];
  rationale: string;
}

/** PATCH /tasks/{id} response: the task, plus the tasks a completion unblocked. */
export type PatchResult = Task & { unlocked_tasks?: Task[] };

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

interface BreakdownStep {
  id: string;
  title: string;
  duration_min?: number;
}

export interface BreakdownProposal {
  task_id: string;
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
    | "duration_min"
    | "deadline"
    | "category"
    | "chips"
    | "resume_note"
  >
> & {
  /** promote (true) or un-promote (false) this task as the hard "do this now" override */
  pinned?: boolean;
};
