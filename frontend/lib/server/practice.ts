import "server-only";

import { apiGet } from "@/lib/server/api";

export interface AIFeedback {
  score: number;
  max_score: number;
  strengths: string[];
  gaps: string[];
  suggested_answer: string;
  follow_up_resources: string[];
  model: string;
}

export interface PracticeItem {
  id: string;
  session_id: string;
  position: number;
  question_text: string;
  user_answer: string | null;
  ai_feedback: AIFeedback | null;
  answered_at: string | null;
  feedback_at: string | null;
  created_at: string;
}

export interface PracticeSession {
  id: string;
  user_id: string;
  technology: string;
  difficulty: string;
  question_count: number;
  status: "active" | "completed" | "abandoned";
  ai_model: string | null;
  created_at: string;
  completed_at: string | null;
  items?: PracticeItem[];
}

export async function getPracticeSessions(): Promise<PracticeSession[]> {
  const data = await apiGet<{ sessions: PracticeSession[] }>("/api/practice/sessions");
  return data.sessions ?? [];
}

export async function getPracticeSession(sessionID: string): Promise<PracticeSession> {
  return apiGet<PracticeSession>(`/api/practice/sessions/${sessionID}`);
}
