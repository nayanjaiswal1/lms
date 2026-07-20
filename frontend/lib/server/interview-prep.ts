import "server-only";

import { apiGet } from "@/lib/server/api";

export interface TestCase {
  stdin: string;
  expected: string;
  hidden: boolean;
}

export interface CodingRunResult {
  status: "passed" | "failed" | "error";
  tests_total: number;
  tests_passed: number;
}

export interface CodingItem {
  id: string;
  prompt: string;
  language: string;
  starter_code: string;
  test_cases: TestCase[];
  skill: string;
  submitted_code?: string;
  run_result?: CodingRunResult | null;
  passed?: boolean | null;
}

export interface PrepRound {
  id: string;
  plan_id: string;
  round_type: "conceptual" | "coding";
  order_index: number;
  practice_session_id?: string | null;
  items?: CodingItem[];
  status: "pending" | "active" | "completed";
  score?: number | null;
  created_at: string;
  completed_at: string | null;
}

export interface PrepReport {
  readiness_score: number;
  conceptual_score_pct: number;
  coding_pass_rate_pct: number;
  strong_skills: string[];
  weak_skills: string[];
  summary: string;
  next_steps: string[];
  cards_added: number;
  ai_model?: string;
}

export interface PrepPlan {
  id: string;
  user_id: string;
  job_title: string;
  jd_text?: string | null;
  extracted_role: string;
  extracted_seniority: string;
  extracted_skills: string[];
  status: "generating" | "ready" | "in_progress" | "completed" | "failed";
  report?: PrepReport | null;
  ai_model?: string | null;
  created_at: string;
  completed_at: string | null;
  rounds?: PrepRound[];
}

export async function listPrepPlans(): Promise<PrepPlan[]> {
  const data = await apiGet<{ plans: PrepPlan[] }>("/api/interview-prep");
  return data.plans ?? [];
}

export async function getPrepPlan(planId: string): Promise<PrepPlan> {
  return apiGet<PrepPlan>(`/api/interview-prep/${planId}`);
}

export async function getPrepReport(planId: string): Promise<PrepReport> {
  return apiGet<PrepReport>(`/api/interview-prep/${planId}/report`);
}
