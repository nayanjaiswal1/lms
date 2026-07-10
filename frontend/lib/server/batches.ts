import "server-only";

import { cookies } from "next/headers";
import { apiGet, authHeaders, baseURL } from "@/lib/server/api";

export interface Batch {
  id: string;
  org_id: string;
  name: string;
  slug: string;
  description: string | null;
  mentor_id: string | null;
  status: string;
  member_count: number;
  starts_at: string | null;
  ends_at: string | null;
  image_url: string | null;
  created_at: string;
}

export interface BatchMember {
  user_id: string;
  name: string;
  email: string;
  added_at: string;
}

export interface BatchMentor {
  user_id: string;
  name: string;
  email: string;
  added_at: string;
}

export interface BatchInvitation {
  id: string;
  email: string;
  invited_at: string;
  expires_at: string;
  accepted_at: string | null;
  declined_at: string | null;
  resent_at: string | null;
}

export interface BatchCourse {
  course_id: string;
  title: string;
  slug: string;
  difficulty: string;
  assigned_at: string;
}

export interface MemberProgress {
  user_id: string;
  name: string;
  email: string;
  courses_enrolled: number;
  courses_completed: number;
  tests_passed: number;
}

export type ImportRowStatus =
  | "new"
  | "existing_active"
  | "pending_invite"
  | "duplicate_in_file"
  | "invalid";

export interface ImportMemberRow {
  full_name: string;
  email: string;
  roll_number?: string;
  phone_number?: string;
  department?: string;
  other_fields?: Record<string, string>;
  status: ImportRowStatus;
  errors?: string[];
}

export interface FailedImportRow {
  email: string;
  full_name: string;
  error_message: string;
}

export interface ImportReport {
  counts: Record<string, number>;
  failed_rows: FailedImportRow[];
}

export async function getBatchImportReport(batchId: string): Promise<ImportReport> {
  return apiGet<ImportReport>(`/api/batches/${batchId}/import/report`);
}

export async function getBatches(): Promise<Batch[]> {
  const data = await apiGet<{ batches: Batch[] }>("/api/batches");
  return data.batches ?? [];
}

export interface MyBatch {
  id: string;
  org_id: string;
  name: string;
  slug: string;
  description: string | null;
  mentor_id: string | null;
  status: string;
  member_count: number;
  starts_at: string | null;
  ends_at: string | null;
  image_url: string | null;
  created_by: string;
  created_at: string;
}

export async function getMyBatches(): Promise<MyBatch[]> {
  try {
    const data = await apiGet<{ batches: MyBatch[] }>("/api/my/batches");
    return data.batches ?? [];
  } catch {
    return [];
  }
}

export async function getBatch(batchId: string): Promise<Batch> {
  const data = await apiGet<{ batch: Batch; members: BatchMember[] }>(`/api/batches/${batchId}`);
  return data.batch;
}

export async function getBatchMembers(batchId: string): Promise<BatchMember[]> {
  const data = await apiGet<{ batch: Batch; members: BatchMember[] }>(`/api/batches/${batchId}`);
  return data.members ?? [];
}

export async function getBatchMentors(batchId: string): Promise<BatchMentor[]> {
  const data = await apiGet<{ mentors: BatchMentor[] }>(`/api/batches/${batchId}/mentors`);
  return data.mentors ?? [];
}

export async function getBatchInvitations(batchId: string): Promise<BatchInvitation[]> {
  const data = await apiGet<{ invitations: BatchInvitation[] }>(`/api/batches/${batchId}/invitations`);
  return data.invitations ?? [];
}

export async function getBatchCourses(batchId: string): Promise<BatchCourse[]> {
  const data = await apiGet<{ courses: BatchCourse[] }>(`/api/batches/${batchId}/courses`);
  return data.courses ?? [];
}

export async function getBatchProgress(batchId: string): Promise<MemberProgress[]> {
  const data = await apiGet<{ progress: MemberProgress[] }>(`/api/batches/${batchId}/progress`);
  return data.progress ?? [];
}

export interface OrgMemberSummary {
  user_id: string;
  name: string;
  email: string;
  role: string;
}

// getOrgId decodes the current user's JWT to extract the org_id claim.
// Returns null when the token is absent or malformed.
export async function getOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

export async function getOrgMembersAll(orgId: string): Promise<OrgMemberSummary[]> {
  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/members`, { headers, cache: "no-store" });
  if (!res.ok) return [];
  const body: { data: { members: Array<{ user_id: string; name: string; email: string; role: string }> } } = await res.json();
  return body.data?.members ?? [];
}
