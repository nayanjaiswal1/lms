import {
  PROJECT_ROLE_RANK,
  type BriefStatus,
  type InterestStatus,
  type MemberStatus,
  type ProjectRole,
  type ProjectStatus,
} from "@/lib/workspace/types";

export function roleAtLeast(role: ProjectRole, min: ProjectRole): boolean {
  return PROJECT_ROLE_RANK[role] >= PROJECT_ROLE_RANK[min];
}

export function canManage(role: ProjectRole): boolean {
  return roleAtLeast(role, "manager");
}

export function isOwner(role: ProjectRole): boolean {
  return role === "owner";
}

export function isTrackLead(trackId: string, ledTrackIds: string[]): boolean {
  return ledTrackIds.includes(trackId);
}

// ── Status/role display maps ────────────────────────────────────────────────
// Small static presentation maps, colocated with the role helpers rather than
// lib/constants.ts (not an owned file for this feature) — same shape as
// APPLICATION_STATUS_LABEL/VARIANT elsewhere in the codebase.

// Mirrors components/ui/badge.tsx's variant union — not imported from there
// directly (a lib/ file can't depend on components/ui/ under the
// eslint-plugin-boundaries layering rules).
type Variant = "default" | "secondary" | "destructive" | "outline";

export const PROJECT_STATUS_LABEL: Record<ProjectStatus, string> = {
  draft: "Draft",
  recruiting: "Recruiting",
  active: "Active",
  paused: "Paused",
  completed: "Completed",
  cancelled: "Cancelled",
  archived: "Archived",
};

export const PROJECT_STATUS_VARIANT: Record<ProjectStatus, Variant> = {
  draft: "outline",
  recruiting: "secondary",
  active: "default",
  paused: "secondary",
  completed: "outline",
  cancelled: "destructive",
  archived: "outline",
};

export const BRIEF_STATUS_LABEL: Record<BriefStatus, string> = {
  raw: "Raw",
  clarifying: "Clarifying",
  agreed: "Agreed",
};

export const MEMBER_STATUS_LABEL: Record<MemberStatus, string> = {
  invited: "Invited",
  active: "Active",
  left: "Left",
  removed: "Removed",
};

export const MEMBER_STATUS_VARIANT: Record<MemberStatus, Variant> = {
  invited: "secondary",
  active: "default",
  left: "outline",
  removed: "destructive",
};

export const INTEREST_STATUS_LABEL: Record<InterestStatus, string> = {
  new: "New",
  accepted: "Accepted",
  rejected: "Rejected",
  invite_expired: "Invite expired",
  joined: "Joined",
};

export const INTEREST_STATUS_VARIANT: Record<InterestStatus, Variant> = {
  new: "secondary",
  accepted: "default",
  rejected: "destructive",
  invite_expired: "outline",
  joined: "default",
};

export const PROJECT_ROLE_LABEL: Record<ProjectRole, string> = {
  owner: "Owner",
  manager: "Manager",
  member: "Member",
  viewer: "Viewer",
};
