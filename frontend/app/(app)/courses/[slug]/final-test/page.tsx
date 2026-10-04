import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { getCourseDetailBySlug, getFinalTest } from "@/lib/server/courses";
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

  const course = await getCourseDetailBySlug(slug).catch(() => null);
  if (!course) notFound();
  if (!course.is_enrolled) redirect(ROUTES.course(slug));

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
