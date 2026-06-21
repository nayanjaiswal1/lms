import "server-only";

import { apiGet } from "@/lib/server/api";

export interface Course {
  id: string;
  org_id: string;
  creator_id: string;
  title: string;
  slug: string;
  description: string | null;
  cover_url: string | null;
  difficulty: string;
  tags: string[];
  status: string;
  forked_from_id: string | null;
  price_cents: number;
  is_free: boolean;
  estimated_hours: number | null;
  created_at: string;
  updated_at: string;
}

export interface CourseModule {
  id: string;
  course_id: string;
  section_id: string;
  title: string;
  type: string;
  position: number;
  is_free_preview: boolean;
  storage_key: string | null;
  duration_seconds: number | null;
  content_body: string | null;
  assessment_id: string | null;
  estimated_minutes: number | null;
}

export interface CourseSection {
  id: string;
  course_id: string;
  title: string;
  position: number;
  modules: CourseModule[];
}

export interface CourseTree extends Course {
  sections: CourseSection[];
}

export interface Enrollment {
  id: string;
  user_id: string;
  course_id: string;
  enrolled_at: string;
  completed_at: string | null;
  course: Course;
}

export interface ModuleProgress {
  module_id: string;
  status: "not_started" | "in_progress" | "completed";
  last_position_seconds: number;
  completed_at: string | null;
}

export interface CourseProgressSummary {
  completed: number;
  total: number;
  pct: number;
  modules: ModuleProgress[];
}

export async function getCourses(query = ""): Promise<Course[]> {
  const data = await apiGet<{ courses: Course[] }>(`/api/courses${query}`);
  return data.courses ?? [];
}

export async function getCourseTree(courseID: string): Promise<CourseTree> {
  return apiGet<CourseTree>(`/api/courses/${courseID}`);
}

export async function getEnrollments(): Promise<Enrollment[]> {
  const data = await apiGet<{ enrollments: Enrollment[] }>("/api/enrollments/me");
  return data.enrollments ?? [];
}

export async function getCourseProgress(courseID: string): Promise<CourseProgressSummary> {
  return apiGet<CourseProgressSummary>(`/api/courses/${courseID}/progress/me`);
}

export interface StudentProgressRow {
  user_id: string;
  name: string;
  email: string;
  completed_modules: number;
  total_modules: number;
  last_active: string | null;
}

export async function getAllStudentProgress(courseID: string): Promise<StudentProgressRow[]> {
  const data = await apiGet<{ progress: StudentProgressRow[] }>(`/api/courses/${courseID}/progress`);
  return data.progress ?? [];
}
