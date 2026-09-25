import { cache } from "react";
import "server-only";

import { apiGet, apiGetPublic } from "@/lib/server/api";

export interface PublicTestInfo {
  id: string;
  title: string;
  description?: string;
  duration_minutes: number;
  question_count: number;
  pass_percentage: number;
}

export interface PublicQuestion {
  assessment_question_id: string;
  question_id: string;
  type: string;
  title: string;
  difficulty: string;
  position: number;
  points: number;
  content: {
    prompt: string;
    multiple?: boolean;
    options?: { id: string; text: string }[];
  };
}

export interface PublicSessionMeta {
  title: string;
  duration_minutes: number;
  allow_backtrack: boolean;
  total_points: number;
  pass_percentage: number;
}

export interface PublicSession {
  session_token: string;
  questions: PublicQuestion[];
  meta: PublicSessionMeta;
}

export interface PublicResult {
  name: string;
  score: number | null;
  max_score: number | null;
  percentage: number | null;
  passed: boolean | null;
  duration_sec: number | null;
  submitted_at: string | null;
}

export interface PublicCandidate {
  id: string;
  assessment_id: string;
  name: string;
  email: string;
  phone?: string;
  score?: number;
  max_score?: number;
  percentage?: number;
  passed?: boolean;
  flags: number;
  status: string;
  started_at: string;
  submitted_at?: string;
  duration_sec?: number;
}

export const getPublicTest = cache(async (code: string): Promise<PublicTestInfo> => {
  return apiGetPublic<PublicTestInfo>(`/api/p/${code}`, { revalidate: 60 });
});

export async function getPublicResult(code: string, token: string): Promise<PublicResult> {
  return apiGetPublic<PublicResult>(`/api/p/${code}/result/${token}`, { revalidate: 60 });
}

export async function getPublicCandidates(assessmentId: string): Promise<PublicCandidate[]> {
  try {
    const data = await apiGet<{ candidates: PublicCandidate[] }>(`/api/assessments/${assessmentId}/candidates`);
    return data?.candidates ?? [];
  } catch {
    return [];
  }
}
