"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { apiAction } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

type LearningGoal = "get_promotion" | "switch_careers" | "build_project" | "stay_current" | "compliance";
type SkillLevel = "beginner" | "some_experience" | "intermediate" | "advanced";

interface OnboardingData {
  learning_goal?: LearningGoal;
  skill_level?: SkillLevel;
  // Legacy fields — kept for backward compatibility
  timeline?: string;
  experience_level?: string;
  role_intent?: string;
  completed?: boolean;
}

export interface OnboardingState {
  error?: string;
}

export async function saveOnboardingAction(data: OnboardingData): Promise<OnboardingState> {
  const store = await cookies();
  if (!store.get("access_token")?.value) {
    redirect(ROUTES.LOGIN);
  }
  const result = await apiAction("POST", "/api/user/onboarding", data);
  if (!result.ok) return { error: result.error ?? "Something went wrong saving your preferences. Please try again." };

  if (data.completed) {
    redirect(ROUTES.DASHBOARD);
  }

  return {};
}
