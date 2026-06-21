import { notFound, redirect } from "next/navigation";
import { getCourses, getCourseTree } from "@/lib/server/courses";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ slug: string }>;
}

export default async function CourseLearnIndexPage({ params }: Props) {
  const { slug } = await params;

  const courses = await getCourses();
  const course = courses.find((c) => c.slug === slug);
  if (!course) notFound();

  const tree = await getCourseTree(course.id).catch(() => null);
  const firstModule = tree?.sections?.[0]?.modules?.[0];

  if (firstModule) {
    redirect(ROUTES.courseLearnModule(slug, firstModule.id));
  }

  notFound();
}
