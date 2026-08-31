import "server-only";

import { apiGet } from "@/lib/server/api";

export interface RoadmapModule {
  id: string;
  milestone_id: string;
  title: string;
  description?: string | null;
  position: number;
  module_type: "course" | "lab" | "dsa_problem" | "project" | "reading" | "quiz";
  resource_type?: "course" | "lab" | "question" | null;
  resource_id?: string | null;
  resource_title?: string | null;
  resource_slug?: string | null;
  estimated_minutes?: number | null;
  completed_at?: string | null;
}

export interface RoadmapMilestone {
  id: string;
  phase_id: string;
  title: string;
  description?: string | null;
  position: number;
  estimated_hours?: number | null;
  modules: RoadmapModule[];
}

export interface RoadmapPhase {
  id: string;
  roadmap_id: string;
  title: string;
  description?: string | null;
  position: number;
  estimated_weeks?: number | null;
  milestones: RoadmapMilestone[];
}

export type RoadmapStatus = "generating" | "active" | "completed" | "archived" | "failed";

export interface Roadmap {
  id: string;
  user_id: string;
  org_id?: string | null;
  title: string;
  mode: "generated" | "defined";
  status: RoadmapStatus;
  is_public: boolean;
  goal_description: string;
  target_role?: string | null;
  skill_level?: string | null;
  timeframe_weeks?: number | null;
  focus_areas: string[];
  generation_error?: string | null;
  generated_at?: string | null;
  created_at: string;
  updated_at: string;
  module_count: number;
  completed_count: number;
  phases?: RoadmapPhase[];
}

// Subset of the onboarding profile used to pre-fill the new-roadmap form —
// see backend/internal/onboarding/handler.go profileResponse for the full shape.
export interface RoadmapProfileDefaults {
  career_goal: string | null;
  learning_goal: string | null;
  skill_level: string | null;
}

export async function listRoadmaps(): Promise<Roadmap[]> {
  const data = await apiGet<{ roadmaps: Roadmap[] }>("/api/roadmaps");
  return data.roadmaps ?? [];
}

export async function listPublicRoadmaps(): Promise<Roadmap[]> {
  const data = await apiGet<{ roadmaps: Roadmap[] }>("/api/roadmaps/discover");
  return data.roadmaps ?? [];
}

export async function getRoadmap(id: string): Promise<Roadmap> {
  return apiGet<Roadmap>(`/api/roadmaps/${id}`);
}

export async function getRoadmapProfileDefaults(): Promise<RoadmapProfileDefaults> {
  return apiGet<RoadmapProfileDefaults>("/api/user/onboarding");
}
