import "server-only";

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

function publicBase(): string {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) throw new Error("BACKEND_URL is not configured");
  return url;
}

export async function getPublicTest(code: string): Promise<PublicTestInfo> {
  const res = await fetch(`${publicBase()}/api/p/${code}`, { cache: "no-store" });
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? "Test not found.");
  }
  const body = await res.json() as { data: PublicTestInfo };
  return body.data;
}

export async function getPublicResult(code: string, token: string): Promise<PublicResult> {
  const res = await fetch(`${publicBase()}/api/p/${code}/result/${token}`, { cache: "no-store" });
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? "Result not found.");
  }
  const body = await res.json() as { data: PublicResult };
  return body.data;
}

export async function getPublicCandidates(assessmentId: string, authHeaders: Record<string, string>): Promise<PublicCandidate[]> {
  const res = await fetch(`${publicBase()}/api/assessments/${assessmentId}/candidates`, {
    headers: authHeaders,
    cache: "no-store",
  });
  if (!res.ok) return [];
  const body = await res.json() as { data: { candidates: PublicCandidate[] } };
  return body.data?.candidates ?? [];
}
