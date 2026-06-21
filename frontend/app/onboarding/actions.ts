"use server";

import { redirect } from "next/navigation";
import { authHeaders } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

type LearningGoal = "get_promotion" | "switch_careers" | "build_project" | "stay_current" | "compliance";
type WeeklyTimeCommitment = "1_2_hrs" | "3_5_hrs" | "5_10_hrs" | "10_plus_hrs";
type SkillLevel = "beginner" | "some_experience" | "intermediate" | "advanced";

interface OnboardingData {
  learning_goal?: LearningGoal;
  job_title?: string;
  topics_interest?: string[];
  weekly_time_commitment?: WeeklyTimeCommitment;
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
  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) return { error: "Onboarding is temporarily unavailable. Please try again later." };

  const headers = await authHeaders();

  // authHeaders includes access_token; redirect to login if it's absent
  if (!headers.Cookie.includes("access_token=") || headers.Cookie.includes("access_token=;")) {
    redirect(ROUTES.LOGIN);
  }

  try {
    const response = await fetch(`${apiUrl}/api/user/onboarding`, {
      method: "POST",
      headers,
      body: JSON.stringify(data),
      cache: "no-store",
    });

    if (!response.ok) {
      const body: unknown = await response.json().catch(() => null);
      const apiError =
        body && typeof body === "object"
          ? (body as Record<string, unknown>).error
          : undefined;
      return {
        error:
          typeof apiError === "string" && apiError.length > 0
            ? apiError
            : "Something went wrong saving your preferences. Please try again.",
      };
    }
  } catch {
    return { error: "We couldn't reach the server. Check your connection and try again." };
  }

  if (data.completed) {
    redirect(ROUTES.DASHBOARD);
  }

  return {};
}
