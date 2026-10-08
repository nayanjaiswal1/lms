import "server-only";

import { apiGet } from "@/lib/server/api";

export interface FunnelCounts {
  enrolled: number;
  started: number;
  reached_25: number;
  reached_50: number;
  reached_75: number;
  completed: number;
}

export interface LessonStat {
  module_id: string;
  title: string;
  type: string;
  section_title: string;
  position: number;
  started: number;
  completed: number;
  completion_rate: number;
  drop_off: number;
}

export interface EnrollmentPoint {
  date: string;
  enrollments: number;
}

export interface CourseAnalytics {
  course_id: string;
  generated_at: string;
  funnel: FunnelCounts;
  lessons: LessonStat[];
  trend: EnrollmentPoint[];
}

interface Paged {
  total: number;
  limit: number;
  offset: number;
}

export interface HardQuestion {
  assessment_question_id: string;
  question_id: string;
  title: string;
  type: string;
  module_id: string;
  module_title: string;
  answered: number;
  students: number;
  correct_rate: number;
}

export interface HardestQuestions extends Paged {
  questions: HardQuestion[];
}

export interface CourseStudent {
  user_id: string;
  name: string;
  email: string;
  enrolled_at: string;
  completed_modules: number;
  total_modules: number;
  progress_pct: number;
  last_active_at: string | null;
  days_inactive: number | null;
  risk_reasons: string[];
}

export interface CourseStudents extends Paged {
  students: CourseStudent[];
}

export interface OrgCourseSummary {
  course_id: string;
  title: string;
  slug: string;
  status: string;
  enrolled: number;
  completed: number;
  avg_progress_pct: number;
  active_last_7d: number;
}

export interface OrgCourseSummaries extends Paged {
  courses: OrgCourseSummary[];
}

export interface StudentQuery {
  risk: "at_risk" | "all";
  inactiveDays: number;
  maxProgressPct: number;
  limit: number;
}

export function getCourseAnalytics(courseID: string, days: number): Promise<CourseAnalytics> {
  const params = new URLSearchParams({ days: String(days) });
  return apiGet<CourseAnalytics>(`/api/courses/${courseID}/analytics?${params}`);
}

export function getHardestQuestions(courseID: string, limit: number): Promise<HardestQuestions> {
  const params = new URLSearchParams({ limit: String(limit) });
  return apiGet<HardestQuestions>(`/api/courses/${courseID}/analytics/questions?${params}`);
}

export function getCourseStudents(courseID: string, q: StudentQuery): Promise<CourseStudents> {
  const params = new URLSearchParams({
    risk: q.risk,
    inactive_days: String(q.inactiveDays),
    max_progress_pct: String(q.maxProgressPct),
    limit: String(q.limit),
  });
  return apiGet<CourseStudents>(`/api/courses/${courseID}/analytics/students?${params}`);
}

export function getOrgCourseSummaries(limit: number): Promise<OrgCourseSummaries> {
  const params = new URLSearchParams({ limit: String(limit) });
  return apiGet<OrgCourseSummaries>(`/api/analytics/courses?${params}`);
}

export async function getOrgEnrollmentTrend(days: number): Promise<EnrollmentPoint[]> {
  const params = new URLSearchParams({ days: String(days) });
  const data = await apiGet<{ points: EnrollmentPoint[] }>(`/api/analytics/enrollment-trend?${params}`);
  return data.points ?? [];
}
