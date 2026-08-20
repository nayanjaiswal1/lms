"use client";

import type { ReactNode } from "react";
import { parseAsStringEnum, useQueryState } from "nuqs";

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

// URL-driven (not useState) so a shared link/refresh lands on the same
// section — same convention as add-people-panel.tsx's "view" query param.
const TAB_VALUES = ["teams", "checkpoints", "originality", "insights"] as const;
type AssignmentTab = (typeof TAB_VALUES)[number];

interface AssignmentTabsProps {
  teamCount: number;
  checkpointCount: number;
  teamsTab: ReactNode;
  checkpointsTab: ReactNode;
  originalityTab: ReactNode;
  insightsTab: ReactNode;
}

export function AssignmentTabs({ teamCount, checkpointCount, teamsTab, checkpointsTab, originalityTab, insightsTab }: AssignmentTabsProps) {
  const [tab, setTab] = useQueryState("tab", parseAsStringEnum<AssignmentTab>([...TAB_VALUES]).withDefault("teams"));

  return (
    <Tabs className="mt-8" value={tab} onValueChange={(next) => void setTab(next as AssignmentTab)}>
      <TabsList>
        <TabsTrigger value="teams">Teams ({teamCount})</TabsTrigger>
        <TabsTrigger value="checkpoints">Checkpoints ({checkpointCount})</TabsTrigger>
        <TabsTrigger value="originality">Originality</TabsTrigger>
        <TabsTrigger value="insights">Leaderboard &amp; burndown</TabsTrigger>
      </TabsList>
      <TabsContent className="mt-6" value="teams">
        {teamsTab}
      </TabsContent>
      <TabsContent className="mt-6" value="checkpoints">
        {checkpointsTab}
      </TabsContent>
      <TabsContent className="mt-6" value="originality">
        {originalityTab}
      </TabsContent>
      <TabsContent className="mt-6" value="insights">
        {insightsTab}
      </TabsContent>
    </Tabs>
  );
}
