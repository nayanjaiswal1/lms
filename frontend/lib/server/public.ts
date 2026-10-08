import { cache } from "react";
import "server-only";

import {  apiGetPublic } from "@/lib/server/api";

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

interface PublicSessionMeta {
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


