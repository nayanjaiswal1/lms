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
  is_public: boolean;
  estimated_hours: number | null;
  instructor_name: string;
  avg_rating: number | null;
  review_count: number;
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

// Anonymous marketplace catalog for the public landing page. Never throws —
// the landing page must still render when the backend is unreachable.
export async function getPublicCourses(
  limit = 12,
): Promise<{ courses: Course[]; total: number }> {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) return { courses: [], total: 0 };
  try {
    const res = await fetch(`${url}/api/public/courses?limit=${limit}`, {
      next: { revalidate: 60 },
    });
    if (!res.ok) return { courses: [], total: 0 };
    const body = (await res.json()) as {
      data?: { courses?: Course[] | null; total?: number };
    };
    return { courses: body.data?.courses ?? [], total: body.data?.total ?? 0 };
  } catch {
    return { courses: [], total: 0 };
  }
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

export async function getMyCheckProgress(moduleID: string): Promise<string[]> {
  const data = await apiGet<{ passed_question_ids: string[] }>(`/api/modules/${moduleID}/check-attempts/me`);
  return data.passed_question_ids ?? [];
}

export async function getMyReflection(moduleID: string): Promise<string | null> {
  const data = await apiGet<{ response: string | null }>(`/api/modules/${moduleID}/reflection/me`);
  return data.response;
}

export async function getMyReview(courseID: string): Promise<number | null> {
  const data = await apiGet<{ rating: number | null }>(`/api/courses/${courseID}/reviews/me`);
  return data.rating;
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
