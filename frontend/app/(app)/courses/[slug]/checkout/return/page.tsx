import { notFound } from "next/navigation";
import { getCourses, getEnrollments, findCourseBySlug } from "@/lib/server/courses";
import { CheckoutStatusPoller } from "./checkout-status-poller";

interface Props {
  params: Promise<{ slug: string }>;
}

export default async function CheckoutReturnPage({ params }: Props) {
  const { slug } = await params;
  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = findCourseBySlug(courses, enrollments, slug);
  if (!course) notFound();

  return (
    <main className="page-container-sm flex min-h-dvh items-center justify-center">
      <CheckoutStatusPoller courseId={course.id} courseSlug={slug} courseTitle={course.title} />
    </main>
  );
}
