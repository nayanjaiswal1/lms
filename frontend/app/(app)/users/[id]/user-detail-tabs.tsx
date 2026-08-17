"use client";

import type { ReactNode } from "react";
import { parseAsStringLiteral, useQueryState } from "nuqs";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export const TAB_VALUES = [
  "overview",
  "courses",
  "sheets",
  "mistakes",
  "habits",
  "journal",
  "access",
  "audit",
] as const;

export type TabValue = (typeof TAB_VALUES)[number];

interface TabDef {
  value: TabValue;
  label: string;
  content: ReactNode;
}

// Tab selection lives in the URL (like every other filter/view-state in this
// app, see app/(app)/users/user-filters.tsx) so a refresh or a shared link
// lands back on the same section of a long, multi-domain page instead of
// always resetting to Overview.
export function UserDetailTabs({ tabs }: { tabs: TabDef[] }) {
  const [tab, setTab] = useQueryState("tab", parseAsStringLiteral(TAB_VALUES).withDefault("overview"));

  return (
    <Tabs className="mt-8" value={tab} onValueChange={(v) => void setTab(v as TabValue)}>
      <TabsList>
        {tabs.map((t) => (
          <TabsTrigger key={t.value} value={t.value}>
            {t.label}
          </TabsTrigger>
        ))}
      </TabsList>
      {tabs.map((t) => (
        <TabsContent key={t.value} value={t.value}>
          {t.content}
        </TabsContent>
      ))}
    </Tabs>
  );
}
