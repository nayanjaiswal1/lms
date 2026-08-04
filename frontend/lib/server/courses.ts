import "server-only";

import { apiGet, apiPost } from "@/lib/server/api";

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
  kind: "org" | "self";
  owner_id: string | null;
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

// EnrollmentProgress is the enrolled course's completion snapshot, embedded
// directly in each Enrollment by GET /api/enrollments/me — no per-course
// getCourseProgress call needed to render enrolled-course cards.
// last_activity_at is the most recent module touched, or null when the
// student hasn't started any module yet (fall back to enrolled_at).
export interface EnrollmentProgress {
  completed: number;
  total: number;
  pct: number;
  last_activity_at: string | null;
}

export interface Enrollment {
  id: string;
  user_id: string;
  course_id: string;
  enrolled_at: string;
  completed_at: string | null;
  course: Course;
  progress: EnrollmentProgress;
}

export interface ModuleProgress {
  module_id: string;
  status: "not_started" | "in_progress" | "completed";
  last_position_seconds: number;
  completed_at: string | null;
  updated_at: string;
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

export interface CourseDetailForViewer extends CourseTree {
  is_enrolled: boolean;
  progress: CourseProgressSummary | null;
  my_rating: number | null;
}

// Resolves a course by its URL slug for the current viewer in a single call
// — enrollment status, progress, and star rating are folded into the
// response server-side, instead of fetching the whole catalog + full
// enrollment list just to find one course by slug, plus separate per-course
// round trips for viewer-specific data.
export async function getCourseDetailBySlug(slug: string): Promise<CourseDetailForViewer> {
  return apiGet<CourseDetailForViewer>(`/api/courses/by-slug/${slug}`);
}

export async function getEnrollments(): Promise<Enrollment[]> {
  const data = await apiGet<{ enrollments: Enrollment[] }>("/api/enrollments/me");
  return data.enrollments ?? [];
}

export interface RandomTopic {
  course: Course;
  matched_interest: boolean;
  already_enrolled: boolean;
}

// "Surprise me" discovery card — one published course the student hasn't
// tried yet. Returns null (not thrown) when the org catalog has no published
// courses at all, since that's a normal empty state for a fresh org, not an
// error the page should crash on.
export async function getRandomTopic(): Promise<RandomTopic | null> {
  try {
    return await apiGet<RandomTopic>("/api/courses/random-topic");
  } catch {
    return null;
  }
}

// `getCourses()` only returns org-scoped courses (kind = 'org') — self-practice
// courses (kind = 'self') never appear there, only in `getEnrollments()` (auto-
// enrolled at creation). Callers resolving a course by slug must check both.
export function findCourseBySlug(courses: Course[], enrollments: Enrollment[], slug: string): Course | undefined {
  return courses.find((c) => c.slug === slug) ?? enrollments.find((e) => e.course.slug === slug)?.course;
}

// Resolves the /courses/{slug}/edit* routes' slug param to a course, scoped
// to courses the caller instructs (role=instructor already covers drafts,
// unlike the plain published-only getCourses() the public catalog uses).
export async function getInstructorCourseBySlug(slug: string): Promise<Course | undefined> {
  const ownCourses = await getCourses("?role=instructor");
  return ownCourses.find((c) => c.slug === slug);
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

export async function getMyLessonNote(moduleID: string): Promise<string | null> {
  const data = await apiGet<{ content: string | null }>(`/api/modules/${moduleID}/notes/me`);
  return data.content;
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

// ─── Final test + certificates ───────────────────────────────────────────────

export interface MCQOption {
  id: string;
  text: string;
  is_correct?: boolean;
}

export interface MCQContent {
  prompt: string;
  multiple: boolean;
  options: MCQOption[];
  explanation?: string;
}

export interface TestCase {
  id: string;
  stdin: string;
  expected: string;
  hidden: boolean;
  weight: number;
}

export interface CodingContent {
  prompt: string;
  languages: string[];
  starter_code: Record<string, string>;
  time_limit_ms: number;
  memory_limit_kb: number;
  test_cases: TestCase[];
}

export interface FinalTestQuestion {
  id: string;
  type: "mcq" | "coding";
  points: number;
  mcq?: MCQContent;
  coding?: CodingContent;
}

export interface StudentFinalTest {
  id: string;
  course_id: string;
  questions: FinalTestQuestion[];
  time_limit_minutes: number;
  passing_score_percent: number;
  max_attempts: number;
  attempts_used: number;
  already_passed: boolean;
  cert_uuid?: string;
}

export interface FinalTestAttempt {
  id: string;
  user_id: string;
  final_test_id: string;
  score: number;
  total: number;
  passed: boolean;
  completed_at: string;
}

export type CertificateIssueType = "final_test" | "manual" | "threshold";

export interface Certificate {
  id: string;
  user_id: string;
  course_id: string;
  final_test_attempt_id: string | null;
  issued_at: string;
  cert_uuid: string;
  issue_type: CertificateIssueType;
  issued_by: string | null;
}

export interface CertificateView extends Certificate {
  course_title: string;
  learner_name: string;
}

export interface CertificateRule {
  id: string;
  course_id: string;
  threshold_percent: number;
  created_at: string;
  updated_at: string;
}

export interface SubmitFinalTestAttemptResult {
  attempt: FinalTestAttempt;
  certificate?: Certificate;
}

// Returns null when the course has no final test, or the learner hasn't
// completed every module yet — both are expected states, not errors, so the
// course page can decide what CTA (if any) to show.
export async function getFinalTest(courseID: string): Promise<StudentFinalTest | null> {
  try {
    return await apiGet<StudentFinalTest>(`/api/courses/${courseID}/final-test`);
  } catch {
    return null;
  }
}

export interface FinalTestConfig {
  id: string;
  course_id: string;
  questions: FinalTestQuestion[];
  time_limit_minutes: number;
  passing_score_percent: number;
  max_attempts: number;
}

// Instructor-only — includes correct answers, for the authoring form. Returns
// null when the course has no final test yet (fresh authoring form).
export async function getFinalTestForEdit(courseID: string): Promise<FinalTestConfig | null> {
  try {
    return await apiGet<FinalTestConfig>(`/api/courses/${courseID}/final-test/edit`);
  } catch {
    return null;
  }
}

export async function getMyCertificates(): Promise<CertificateView[]> {
  const data = await apiGet<CertificateView[]>("/api/certificates/me");
  return data ?? [];
}

// The caller's own certificate for one course, if any — scoped to (user,
// course) rather than fetching every certificate the learner has ever earned
// and filtering client-side. Never throws: no certificate yet is a normal
// state, not an error the course page should crash on.
export async function getMyCertificateForCourse(courseID: string): Promise<Certificate | null> {
  try {
    return await apiGet<Certificate | null>(`/api/courses/${courseID}/certificates/me`);
  } catch {
    return null;
  }
}

// Instructor-only — returns null when the course has no threshold rule
// configured yet (a normal, not-yet-set-up state).
export async function getCertificateRule(courseID: string): Promise<CertificateRule | null> {
  try {
    return await apiGet<CertificateRule | null>(`/api/courses/${courseID}/certificate-rule`);
  } catch {
    return null;
  }
}

// Evaluates and, if eligible, issues the caller's own threshold-based
// certificate for this course. Safe to call on every course-page render —
// a no-op once a certificate already exists or no rule is configured.
// Never throws: an unreachable backend just means no certificate this load.
export async function checkThresholdCertificate(courseID: string): Promise<Certificate | null> {
  try {
    return await apiPost<Certificate | null>(`/api/courses/${courseID}/certificates/check-threshold`);
  } catch {
    return null;
  }
}
