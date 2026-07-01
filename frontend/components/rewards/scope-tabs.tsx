"use client";

import { useRouter, usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

export type LeaderboardScope = "global" | "org" | "batch" | "course" | "feature";

interface ScopeTab {
  scope: LeaderboardScope;
  label: string;
  scopeId?: string;
  featureType?: string;
}

interface ScopeTabsProps {
  tabs: ScopeTab[];
  activeScope: LeaderboardScope;
  activeScopeId?: string;
  activeFeatureType?: string;
}

export function ScopeTabs({ tabs, activeScope, activeScopeId, activeFeatureType }: ScopeTabsProps) {
  const router = useRouter();
  const pathname = usePathname();

  function isActive(tab: ScopeTab) {
    if (tab.scope !== activeScope) return false;
    if (tab.scopeId !== activeScopeId) return false;
    if (tab.featureType !== activeFeatureType) return false;
    return true;
  }

  function handleSelect(tab: ScopeTab) {
    const params = new URLSearchParams({ scope: tab.scope });
    if (tab.scopeId) params.set("scope_id", tab.scopeId);
    if (tab.featureType) params.set("feature_type", tab.featureType);
    router.push(`${pathname}?${params.toString()}`);
  }

  return (
    <div
      role="tablist"
      aria-label="Leaderboard scope"
      className="flex flex-wrap gap-1 rounded-xl border border-border bg-muted/40 p-1"
    >
      {tabs.map((tab) => {
        const active = isActive(tab);
        return (
          <button
            key={`${tab.scope}-${tab.scopeId ?? ""}-${tab.featureType ?? ""}`}
            role="tab"
            aria-selected={active}
            onClick={() => handleSelect(tab)}
            className={cn(
              "rounded-lg px-3 py-1.5 text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
              active
                ? "bg-background text-foreground shadow-sm"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            {tab.label}
          </button>
        );
      })}
    </div>
  );
}
