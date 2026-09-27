"use client";

import { useState } from "react";

import { StandupForm } from "@/components/workspace/meetings/standup-form";
import { StandupList } from "@/components/workspace/meetings/standup-list";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import type { Standup } from "@/lib/workspace/types";

interface StandupsPanelProps {
  workspaceId: string;
  currentUserId: string;
  initialStandups: Standup[];
}

export function StandupsPanel({ workspaceId, currentUserId, initialStandups }: StandupsPanelProps) {
  const { atLeast } = useProjectRole();
  const [standups, setStandups] = useState(initialStandups);
  const mine = standups.find((s) => s.user_id === currentUserId) ?? null;

  function upsert(standup: Standup) {
    setStandups((prev) => (prev.some((s) => s.user_id === standup.user_id)
      ? prev.map((s) => (s.user_id === standup.user_id ? standup : s))
      : [...prev, standup]));
  }

  return (
    <div className="flex flex-col gap-4">
      <h2 className="subsection-title">Standups — today</h2>
      {atLeast("member") && <StandupForm mine={mine} workspaceId={workspaceId} onPosted={upsert} />}
      <StandupList standups={standups} workspaceId={workspaceId} />
    </div>
  );
}
