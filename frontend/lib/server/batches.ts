import "server-only";

import { apiGet, authHeaders, baseURL } from "@/lib/server/api";
import { getCurrentOrgId } from "@/lib/server/claims";

export interface Batch {
  id: string;
  org_id: string;
  name: string;
  slug: string;
  description: string | null;
  mentor_id: string | null;
  status: string;
  member_count: number;
  unresolved_count: number;
  starts_at: string | null;
  ends_at: string | null;
  image_url: string | null;
  cohort_group_id: string | null;
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
  import_job_id: string | null;
}

export interface BatchCourse {
  course_id: string;
  title: string;
  slug: string;
  difficulty: string;
  assigned_at: string;
}

export type MemberStatus = "on_track" | "needs_support" | "not_engaged";

export interface MemberProgress {
  user_id: string;
  name: string;
  email: string;
  courses_enrolled: number;
  courses_completed: number;
  tests_passed: number;
  avg_hints: number;
  xp_total: number;
  last_active_at: string | null;
  status: MemberStatus;
}

export interface ClassHealth {
  total_students: number;
  on_track_pct: number;
  needs_support_pct: number;
  not_engaged_pct: number;
}

export type MasteryStatus = "mastered" | "needs_practice" | "needs_review" | "insufficient_data";

export interface ChapterMasteryCell {
  user_id: string;
  user_name: string;
  section_id: string;
  section_title: string;
  avg_hints: number | null;
  status: MasteryStatus;
}

export interface ChapterHintStat {
  section_id: string;
  section_title: string;
  avg_hints: number;
  student_count: number;
}

export interface BlockerBucket {
  category: string;
  count: number;
}

export interface BlockersBreakdown {
  buckets: BlockerBucket[];
  estimated: boolean;
}

export interface EngagementPoint {
  user_id: string;
  user_name: string;
  days_active: number;
  problems_solved: number;
}

export interface BatchAnalytics {
  health: ClassHealth;
  roster: MemberProgress[];
  chapter_mastery: ChapterMasteryCell[];
  chapter_hint_ranking: ChapterHintStat[];
  blockers: BlockersBreakdown;
  engagement: EngagementPoint[];
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
  cohort_group_id: string | null;
  cohort_group_name?: string | null; // omitted entirely by the API when null (Go `omitempty`)
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

export interface BatchRoster {
  members: BatchMember[];
  mentors: BatchMentor[];
}

// getBatchRoster fetches members and mentors in a single call — GET
// /api/batches/{id} already returns both, so callers that need the combined
// people list (e.g. the batch detail page) should use this instead of
// calling getBatchMembers + getBatchMentors separately and merging client-side.
export async function getBatchRoster(batchId: string): Promise<BatchRoster> {
  const data = await apiGet<{ batch: Batch; members: BatchMember[]; mentors: BatchMentor[] }>(
    `/api/batches/${batchId}`,
  );
  return { members: data.members ?? [], mentors: data.mentors ?? [] };
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

export async function getBatchAnalytics(batchId: string): Promise<BatchAnalytics> {
  return apiGet<BatchAnalytics>(`/api/batches/${batchId}/analytics`);
}

export interface OfflineTestSummary {
  test_id: string;
  test_name: string;
  test_date: string;
  max_score: number;
  student_count: number;
  avg_score: number;
}

export interface OfflineTestScoreRow {
  user_id: string;
  user_name: string;
  email: string;
  score: number;
}

export interface OfflineTestDetail {
  test_id: string;
  test_name: string;
  test_date: string;
  max_score: number;
  scores: OfflineTestScoreRow[];
}

export async function listOfflineTests(batchId: string): Promise<OfflineTestSummary[]> {
  const data = await apiGet<{ tests: OfflineTestSummary[] }>(`/api/batches/${batchId}/offline-tests`);
  return data.tests ?? [];
}

export async function getOfflineTest(batchId: string, testId: string): Promise<OfflineTestDetail> {
  return apiGet<OfflineTestDetail>(`/api/batches/${batchId}/offline-tests/${testId}`);
}

export interface OrgMemberSummary {
  user_id: string;
  name: string;
  email: string;
  role: string;
}

// getOrgId decodes the current user's JWT to extract the org_id claim.
// Returns null when the token is absent or malformed.

/** @deprecated Prefer getCurrentOrgId from @/lib/server/claims directly. */
export async function getOrgId(): Promise<string | null> {
  return getCurrentOrgId();
}

export async function getOrgMembersAll(orgId: string): Promise<OrgMemberSummary[]> {
  const headers = await authHeaders();
  const res = await fetch(`${baseURL()}/api/orgs/${orgId}/members`, { headers, cache: "no-store" });
  if (!res.ok) return [];
  const body: { data: { members: Array<{ user_id: string; name: string; email: string; role: string }> } } = await res.json();
  return body.data?.members ?? [];
}
