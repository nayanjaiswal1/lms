import { notFound } from "next/navigation";
import { Clock, Tag } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { getCourses, getEnrollments } from "@/lib/server/courses";
import { enrollAction } from "@/lib/courses/actions";
import ROUTES from "@/lib/routes";
import Link from "next/link";

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { slug } = await params;
  return { title: `${slug} — MindForge` };
}

export default async function CourseDetailPage({ params }: Props) {
  const { slug } = await params;

  const [courses, enrollments] = await Promise.all([getCourses(), getEnrollments()]);
  const course = courses.find((c) => c.slug === slug);
  if (!course) notFound();

  const courseId = course.id;
  const enrollment = enrollments.find((e) => e.course_id === courseId);

  async function handleEnroll() {
    "use server";
    await enrollAction(courseId);
  }

  return (
    <main className="page-container py-8">
      <div className="flex flex-col gap-8 lg:flex-row lg:gap-12">
        <article className="flex flex-1 flex-col gap-6">
          <div>
            <div className="mb-2 flex flex-wrap items-center gap-2">
              <span className={`difficulty-${course.difficulty}`}>{course.difficulty}</span>
              {course.is_free && <Badge variant="secondary">Free</Badge>}
            </div>
            <h1 className="page-title">{course.title}</h1>
            {course.description && (
              <p className="mt-3 text-muted-foreground">{course.description}</p>
            )}
          </div>

          <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
            {course.estimated_hours && (
              <span className="flex items-center gap-1.5">
                <Clock aria-hidden className="h-4 w-4" />
                {course.estimated_hours} hours
              </span>
            )}
            {course.tags.length > 0 && (
              <div className="flex items-center gap-1.5">
                <Tag aria-hidden className="h-4 w-4" />
                {course.tags.map((tag) => (
                  <Badge className="text-xs" key={tag} variant="outline">{tag}</Badge>
                ))}
              </div>
            )}
          </div>
        </article>

        <aside className="w-full lg:w-72">
          <div className="card-raised flex flex-col gap-4 p-6">
            {enrollment ? (
              <>
                <p className="text-sm text-primary font-medium">You are enrolled</p>
                <Button asChild>
                  <Link href={ROUTES.courseLearn(course.slug)}>Continue learning</Link>
                </Button>
              </>
            ) : (
              <>
                {!course.is_free && (
                  <p className="text-2xl font-bold">
                    ${(course.price_cents / 100).toFixed(2)}
                  </p>
                )}
                <form action={handleEnroll}>
                  <Button className="w-full" type="submit">
                    {course.is_free ? "Enroll for free" : "Enroll now"}
                  </Button>
                </form>
              </>
            )}
          </div>
        </aside>
      </div>
    </main>
  );
}
