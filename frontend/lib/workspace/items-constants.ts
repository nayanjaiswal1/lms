// Presentation maps for work items — colocated with lib/workspace/roles.ts's
// existing STATUS_LABEL/VARIANT pattern, kept in this feature's own lib file
// (items-server.ts/items-actions.ts) rather than roles.ts since that file is
// lead-owned territory for the Phase 1 project-level types.
import {
  Bug,
  Bookmark,
  CircleDot,
  Flag,
  ListTree,
} from "lucide-react";
import type {
  BugSeverity,
  DocStatus,
  ItemPriority,
  ItemStatus,
  ItemType,
} from "@/lib/workspace/types";

type Variant = "default" | "secondary" | "destructive" | "outline";

export const ITEM_TYPE_LABEL: Record<ItemType, string> = {
  epic: "Epic",
  feature: "Feature",
  task: "Task",
  bug: "Bug",
  subtask: "Subtask",
};

export const ITEM_TYPE_ICON: Record<ItemType, typeof Bug> = {
  epic: Bookmark,
  feature: Flag,
  task: CircleDot,
  bug: Bug,
  subtask: ListTree,
};

export const ITEM_STATUS_LABEL: Record<ItemStatus, string> = {
  todo: "To do",
  in_progress: "In progress",
  in_review: "In review",
  testing: "Testing",
  done: "Done",
  blocked: "Blocked",
  reopened: "Reopened",
  wont_do: "Won't do",
};

export const ITEM_STATUS_VARIANT: Record<ItemStatus, Variant> = {
  todo: "outline",
  in_progress: "secondary",
  in_review: "secondary",
  testing: "secondary",
  done: "default",
  blocked: "destructive",
  reopened: "destructive",
  wont_do: "outline",
};


// Board columns exclude epic/feature (roll-up only, no direct board card) and
// wont_do (closed, lives in the list/filter view instead of taking board space).
export const BOARD_STATUSES: ItemStatus[] = ["todo", "in_progress", "in_review", "testing", "done", "blocked", "reopened"];


export const ITEM_PRIORITY_VARIANT: Record<ItemPriority, Variant> = {
  low: "outline",
  medium: "secondary",
  high: "default",
  urgent: "destructive",
};


export const BUG_SEVERITY_VARIANT: Record<BugSeverity, Variant> = {
  S1: "destructive",
  S2: "destructive",
  S3: "secondary",
  S4: "outline",
};

// Phase 3 — feature doc-review gate (contract-phase3.md's DocStatusMachine).
export const DOC_STATUS_LABEL: Record<DocStatus, string> = {
  draft: "Draft",
  in_review: "In review",
  changes_requested: "Changes requested",
  approved: "Approved",
};


// Derived from statemachine.go HierarchyRules (ITEM_CHILD_TYPES in types.ts):
// which parent *type(s)* a given item type may attach to, and whether a
// parent is mandatory. Root-level creation (no parent) is allowed only where
// ITEM_CHILD_TYPES[""] lists the type (epic, bug).
export const PARENT_TYPE_OPTIONS: Record<ItemType, ItemType[]> = {
  epic: [],
  feature: ["epic"],
  task: ["feature"],
  bug: ["epic", "feature"],
  subtask: ["task", "bug"],
};

export const PARENT_REQUIRED: Record<ItemType, boolean> = {
  epic: false,
  feature: true,
  task: true,
  bug: false,
  subtask: true,
};

// Transitions the UI must collect a reason for before calling the backend
// (statemachine.go rules — see contract-phase2.md "Transition"); blocked also
// needs a blocker item.
export const TRANSITION_NEEDS_REASON = new Set<ItemStatus>(["blocked", "wont_do", "reopened"]);
