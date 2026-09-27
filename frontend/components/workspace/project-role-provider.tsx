"use client";

import { createContext, useContext, useMemo, type ReactNode } from "react";
import type { ProjectRole } from "@/lib/workspace/types";
import { canManage, isOwner, isTrackLead, roleAtLeast } from "@/lib/workspace/roles";

export interface ProjectRoleContextValue {
  role: ProjectRole;
  isOverseer: boolean;
  myTrackIds: string[];
  ledTrackIds: string[];
  /** True when `role` outranks or equals `min` on the viewer/member/manager/owner scale. */
  atLeast: (min: ProjectRole) => boolean;
  /** True when role is manager or owner. */
  canManage: boolean;
  /** True when role is owner. */
  isOwner: boolean;
  /** True when the caller leads the given track (from `led_track_ids`). */
  isLeadOf: (trackId: string) => boolean;
}

const ProjectRoleContext = createContext<ProjectRoleContextValue | null>(null);

interface ProjectRoleProviderProps {
  role: ProjectRole;
  isOverseer: boolean;
  myTrackIds: string[];
  ledTrackIds: string[];
  children: ReactNode;
}

/** Wraps a workspace's page tree with the caller's role for that one project
 * (embedded server-side on ProjectDetail — no extra round trip). */
export function ProjectRoleProvider({ role, isOverseer, myTrackIds, ledTrackIds, children }: ProjectRoleProviderProps) {
  const value = useMemo<ProjectRoleContextValue>(
    () => ({
      role,
      isOverseer,
      myTrackIds,
      ledTrackIds,
      atLeast: (min) => roleAtLeast(role, min),
      canManage: canManage(role),
      isOwner: isOwner(role),
      isLeadOf: (trackId) => isTrackLead(trackId, ledTrackIds),
    }),
    [role, isOverseer, myTrackIds, ledTrackIds],
  );

  return <ProjectRoleContext.Provider value={value}>{children}</ProjectRoleContext.Provider>;
}

export function useProjectRole(): ProjectRoleContextValue {
  const ctx = useContext(ProjectRoleContext);
  if (!ctx) throw new Error("useProjectRole must be used within ProjectRoleProvider");
  return ctx;
}
