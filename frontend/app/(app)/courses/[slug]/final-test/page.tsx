import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { findCourseBySlug, getCourses, getEnrollments } from "@/lib/server/courses";
import { getFinalTest } from "@/lib/server/courses";
import { FinalTestClient } from "@/components/courses/final-test-client";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  return { title: `Final Test — ${slug}` };
}

export default async function FinalTestPage({ params }: Props) {
  const { slug } = await params;

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  const isEnrolled = enrollments.some((e) => e.course_id === course.id);
  if (!isEnrolled) redirect(ROUTES.course(slug));

  const finalTest = await getFinalTest(course.id);
  if (!finalTest) redirect(ROUTES.course(slug));

  if (finalTest.already_passed) {
    redirect(finalTest.cert_uuid ? ROUTES.certificate(finalTest.cert_uuid) : ROUTES.course(slug));
  }
  if (finalTest.attempts_used >= finalTest.max_attempts) {
    redirect(ROUTES.course(slug));
  }

  return (
    <main className="page-container-sm">
      <Breadcrumb
        items={[
          { label: "Courses", href: ROUTES.COURSES },
          { label: course.title, href: ROUTES.course(slug) },
          { label: "Final Test" },
        ]}
      />

      <FinalTestClient courseId={course.id} courseSlug={slug} courseTitle={course.title} finalTest={finalTest} />
    </main>
  );
}
