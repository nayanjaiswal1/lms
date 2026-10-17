import "server-only";

import { apiGet } from "@/lib/server/api";

export interface LabUsageRow {
  lab_id: string;
  lab_title: string;
  image: string;
  sessions: number;
  container_seconds: number;
}

export interface CourseLabUsageRow {
  course_id: string;
  course_title: string;
  sessions: number;
  student_count: number;
  container_seconds: number;
}

export interface StudentLabUsageRow {
  user_id: string;
  name: string;
  email: string;
  sessions: number;
  container_seconds: number;
}

export interface OrgLabUsage {
  total_container_seconds: number;
  total_sessions: number;
  by_lab: LabUsageRow[];
}

export interface LabUsageResponse {
  window_days: number;
  org: OrgLabUsage;
  by_course: CourseLabUsageRow[];
  by_student: StudentLabUsageRow[];
}

// getLabUsage requires admin.manage_org; callers gate before calling.
// studentLimit omitted uses the backend default.
export function getLabUsage(days: number, studentLimit?: number): Promise<LabUsageResponse> {
  const params = new URLSearchParams({ days: String(days) });
  if (studentLimit) params.set("student_limit", String(studentLimit));
  return apiGet<LabUsageResponse>(`/api/admin/labs/usage?${params}`);
}
