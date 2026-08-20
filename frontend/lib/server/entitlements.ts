import "server-only";

import { apiGet } from "@/lib/server/api";

export interface UsageStatus {
  feature_key: string;
  used: number;
  limit: number;
  period: string;
}

export interface MyUsage {
  tier_id: string;
  tier_name: string;
  usage: UsageStatus[];
}

/** The current account's plan + quota standing (My Plan page). Individual accounts only see usage rows for keys their tier has a numeric limit on — see backend/internal/entitlements. */
export async function getMyUsage(): Promise<MyUsage> {
  try {
    return await apiGet<MyUsage>("/api/me/usage");
  } catch {
    return { tier_id: "", tier_name: "", usage: [] };
  }
}

export interface PlanLimit {
  tier_id: string;
  feature_key: string;
  kind: "gate" | "quota" | "unlimited";
  bool_value?: boolean;
  numeric_value?: number;
  period?: string;
  updated_at: string;
}

/** Every editable plan_limits row for one tier, for the platform admin's limits editor. */
export async function getAdminPlanLimits(tierId: string): Promise<PlanLimit[]> {
  const { limits } = await apiGet<{ limits: PlanLimit[] }>(`/api/admin/plan-limits/${tierId}`);
  return limits;
}
